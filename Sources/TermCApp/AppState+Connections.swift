import Foundation
import TermCCore

extension AppState {
    var favoriteConnections: [ConnectionRecord] {
        connections.filter(\.isFavorite)
    }

    var historyConnections: [ConnectionRecord] {
        connections.filter { !$0.isFavorite }
    }

    var recentConnections: [ConnectionRecord] {
        connections
            .filter { $0.lastConnectedAt != nil }
            .sorted {
                ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast)
            }
            .prefix(5)
            .map { $0 }
    }

    var connectionTags: [String] {
        Array(Set(connections.flatMap(\.tags))).sorted()
    }

    var connectionGroups: [String] {
        Array(Set(connections.compactMap { connection in
            let group = connection.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return group.isEmpty ? nil : group
        })).sorted()
    }

    func clearHistory() {
        connections.removeAll { !$0.isFavorite }
        Task {
            await persistConnections()
        }
    }

    func deleteConnection(_ id: ConnectionRecord.ID) {
        connections.removeAll { $0.id == id }
        Task {
            await persistConnections()
        }
    }

    func deleteHistoryConnection(_ id: ConnectionRecord.ID) {
        connections.removeAll { $0.id == id && !$0.isFavorite }
        Task {
            await persistConnections()
        }
    }

    func toggleFavorite(_ id: ConnectionRecord.ID) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else {
            return
        }

        connections[index].isFavorite.toggle()
        connections[index].updatedAt = Date()
        Task {
            await persistConnections()
        }
    }

    func exportConnections() throws -> Data {
        try ImportExportService().export(connections)
    }

    func importConnections(from data: Data) async throws {
        let importedConnections = try ImportExportService().import(data)
        var existingKeys = Set(connections.map(importKey))
        var nextConnections = connections

        for connection in importedConnections {
            let key = importKey(for: connection)
            guard !existingKeys.contains(key) else {
                continue
            }

            existingKeys.insert(key)
            nextConnections.append(connection)
        }

        connections = nextConnections
        await persistConnections()
    }

    func beginNewConnection() {
        draftAlias = ""
        draftGroup = ""
        draftHost = ""
        draftPort = "22"
        draftUsername = ""
        draftPassword = ""
        draftUsesKey = false
        draftPrivateKeyPath = ""
        draftPrivateKeyPassphrase = ""
        draftTags = ""
        draftKeepAliveEnabled = false
        draftKeepAliveInterval = "30"
        draftKeepAliveMaxCount = "3"
        draftJumpHost = ""
        draftDefaultRemotePath = ""
        draftForwardEnabled = false
        draftForwardDirection = .local
        draftForwardBindAddress = "127.0.0.1"
        draftForwardLocalPort = ""
        draftForwardDestinationHost = ""
        draftForwardDestinationPort = ""
        isConnectionFormPresented = true
    }

    func saveDraftConnection() {
        guard let connection = makeDraftConnection() else {
            return
        }

        connections.append(connection)
        isConnectionFormPresented = false
        Task {
            await persistConnections()
        }
    }

    func connectDraftConnection() async {
        guard let connection = makeDraftConnection() else {
            return
        }

        connections.append(connection)
        isConnectionFormPresented = false
        await persistConnections()

        let credential: Credential? = if connection.authentication.kind == .password {
            .password(draftPassword)
        } else if draftPrivateKeyPassphrase.isEmpty {
            nil
        } else {
            .privateKeyPassphrase(draftPrivateKeyPassphrase)
        }

        if let credential {
            try? await credentialStore.save(credential, for: connection.id)
        }

        await connect(connection, credential: credential)
    }

    func connect(_ connection: ConnectionRecord) async {
        let credential = try? await credentialStore.load(for: connection.id)
        await connect(connection, credential: credential)
    }

    func loadConnections() async {
        do {
            let snapshot = try await connectionStore.load()
            connections = snapshot.connections
        } catch {
            connections = []
        }
    }

    func persistConnections() async {
        do {
            try await connectionStore.replaceConnections(connections)
        } catch {
            // Persistence errors should not block an active terminal session.
        }
    }

    func connect(_ connection: ConnectionRecord, credential: Credential?) async {
        let connection = markConnectionUsed(connection)
        let tab = TerminalTab(
            title: connection.alias,
            state: .connecting,
            transcript: "\(t.connectingTo) \(connection.username)@\(connection.host):\(connection.port)...\n"
        )
        tabs.append(tab)
        selectedTabID = tab.id
        setRemotePath(connection.defaultRemotePath ?? ".", for: tab.id)

        if connection.requiresLocalSSHOnly {
            updateTab(
                id: tab.id,
                state: .connected,
                transcript: """
                \(t.connectedTo) \(connection.username)@\(connection.host):\(connection.port)

                """
            )
            attachSession(LocalSSHOnlySession(record: connection), to: tab.id)
            attachLocalSSHProcess(to: tab.id, connection: connection, credential: credential)
            await refreshRemoteFiles()
            return
        }

        do {
            let session = try await connectWithTimeout(record: connection, credential: credential)
            updateTab(
                id: tab.id,
                state: .connected,
                transcript: """
                \(t.connectedTo) \(connection.username)@\(connection.host):\(connection.port)

                """
            )
            attachSession(session, to: tab.id)
            attachLocalSSHProcess(to: tab.id, connection: connection, credential: credential)
            await refreshRemoteFiles()
        } catch {
            let message = String(describing: error)
            updateTab(
                id: tab.id,
                state: .failed(message),
                transcript: """
                \(t.failedToConnect) \(connection.username)@\(connection.host):\(connection.port)
                \(message)

                """
            )
        }
    }

    func connectWithTimeout(
        record: ConnectionRecord,
        credential: Credential?
    ) async throws -> SSHSessionProviding {
        let timeoutMessage = t.connectionTimedOut(seconds: connectionTimeoutSeconds)
        return try await withThrowingTaskGroup(of: SSHSessionProviding.self) { group in
            group.addTask {
                try await self.sshClient.connect(record: record, credential: credential)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeoutSeconds))
                throw SSHConnectionTimeoutError(message: timeoutMessage)
            }

            guard let session = try await group.next() else {
                throw SSHConnectionTimeoutError(message: timeoutMessage)
            }
            group.cancelAll()
            return session
        }
    }

    func makeDraftConnection() -> ConnectionRecord? {
        let alias = draftAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = draftGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let jumpHost = draftJumpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultRemotePath = draftDefaultRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepAliveInterval = Int(draftKeepAliveInterval.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 30
        let keepAliveMaxCount = Int(draftKeepAliveMaxCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3
        let forwardLocalPort = UInt16(draftForwardLocalPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationPort = UInt16(draftForwardDestinationPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationHost = draftForwardDestinationHost.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let port = UInt16(draftPort.trimmingCharacters(in: .whitespacesAndNewlines)),
            port > 0,
            !host.isEmpty,
            !username.isEmpty,
            !draftUsesKey || !privateKeyPath.isEmpty,
            !draftKeepAliveEnabled || (keepAliveInterval > 0 && keepAliveMaxCount > 0),
            !draftForwardEnabled || forwardLocalPort != nil,
            !draftForwardEnabled || draftForwardDirection == .dynamic || (!forwardDestinationHost.isEmpty && forwardDestinationPort != nil)
        else {
            return nil
        }

        let authentication: ConnectionAuthentication = draftUsesKey
            ? .publicKey(privateKeyPath: privateKeyPath)
            : .password
        return ConnectionRecord(
            alias: alias.isEmpty ? host : alias,
            host: host,
            port: port,
            username: username,
            authentication: authentication,
            tags: parseTags(draftTags),
            group: group.isEmpty ? nil : group,
            keepAlive: .init(
                isEnabled: draftKeepAliveEnabled,
                intervalSeconds: keepAliveInterval,
                maxCount: keepAliveMaxCount
            ),
            jumpHost: jumpHost.isEmpty ? nil : jumpHost,
            portForwards: makeDraftPortForwards(
                localPort: forwardLocalPort,
                destinationHost: forwardDestinationHost,
                destinationPort: forwardDestinationPort
            ),
            defaultRemotePath: defaultRemotePath.isEmpty ? nil : defaultRemotePath
        )
    }

    func parseTags(_ value: String) -> [String] {
        value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func importKey(for connection: ConnectionRecord) -> String {
        "\(connection.host):\(connection.port):\(connection.username):\(connection.alias)"
    }

    func makeDraftPortForwards(
        localPort: UInt16?,
        destinationHost: String,
        destinationPort: UInt16?
    ) -> [ConnectionRecord.PortForward] {
        guard draftForwardEnabled, let localPort else {
            return []
        }

        return [
            .init(
                direction: draftForwardDirection,
                bindAddress: draftForwardBindAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                localPort: localPort,
                destinationHost: destinationHost,
                destinationPort: destinationPort ?? 0
            )
        ]
    }

    func markConnectionUsed(_ connection: ConnectionRecord) -> ConnectionRecord {
        var connection = connection
        connection.lastConnectedAt = Date()
        connection.updatedAt = Date()

        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        }

        Task {
            await persistConnections()
        }
        return connection
    }
}
