import Foundation
import TermTPCore

extension AppState {
    var favoriteConnections: [ConnectionRecord] {
        connections.filter(\.isFavorite)
    }

    var historyConnections: [ConnectionRecord] {
        connections.filter(\.isHistoryVisible)
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
        for index in connections.indices {
            connections[index].isHistoryVisible = false
            connections[index].updatedAt = Date()
        }
        Task {
            await persistConnections()
        }
    }

    func deleteConnection(_ id: ConnectionRecord.ID) {
        connections.removeAll { $0.id == id }
        Task {
            try? await credentialStore.delete(for: id)
            await persistConnections()
        }
    }

    func deleteHistoryConnection(_ id: ConnectionRecord.ID) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else {
            return
        }

        connections[index].isHistoryVisible = false
        connections[index].updatedAt = Date()
        Task {
            await persistConnections()
        }
    }

    func deleteFavoriteConnection(_ id: ConnectionRecord.ID) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else {
            return
        }

        connections[index].isFavorite = false
        connections[index].updatedAt = Date()
        Task {
            await persistConnections()
        }
    }

    func deleteRecentConnection(_ id: ConnectionRecord.ID) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else {
            return
        }

        connections[index].lastConnectedAt = nil
        connections[index].updatedAt = Date()
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

        isConnectionFormPresented = false

        let password = draftPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPassphrase = draftPrivateKeyPassphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let credential: Credential? = switch connection.authentication {
        case .password:
            password.isEmpty ? nil : .password(password)
        case .publicKey:
            privateKeyPassphrase.isEmpty ? nil : .privateKeyPassphrase(privateKeyPassphrase)
        }

        await connect(connection, credential: credential, persistsNewConnection: true)
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
            _ = try? await connectionStore.backupCorruptStore()
            showNotification(kind: .error, message: t.loadConnectionsFailed(String(describing: error)))
        }
    }

    func migrateLegacyFileCredentialsIfNeeded() async {
        guard !(credentialStore is FileCredentialStore) else {
            return
        }

        do {
            let credentials = try await legacyCredentialStore.loadAll()
            guard !credentials.isEmpty else {
                return
            }

            for (connectionID, credential) in credentials {
                try await credentialStore.save(credential, for: connectionID)
            }

            try await legacyCredentialStore.removeStoreFile()
        } catch {
            // Keep the legacy file in place if migration fails so credentials are not lost.
        }
    }

    func persistConnections() async {
        do {
            try await connectionStore.replaceConnections(connections)
        } catch {
            // Persistence errors should not block an active terminal session.
        }
    }

    func connect(
        _ connection: ConnectionRecord,
        credential: Credential?,
        persistsNewConnection: Bool = false
    ) async {
        var connection = connection
        let tab = TerminalTab(
            title: connection.alias,
            state: .connecting,
            transcript: "\(t.connectingTo) \(connection.username)@\(connection.host):\(connection.port)...\n"
        )
        tabs.append(tab)
        selectedTabID = tab.id
        setRemotePath(connection.defaultRemotePath ?? ".", for: tab.id)

        if requiresLocalSSHOnly(connection, credential: credential) {
            connection = markConnectionConnected(connection)
            if persistsNewConnection {
                connections.append(connection)
                await persistConnections()
                if let credential {
                    try? await credentialStore.save(credential, for: connection.id)
                }
            }
            updateTab(
                id: tab.id,
                state: .connected,
                transcript: """
                \(t.connectedTo) \(connection.username)@\(connection.host):\(connection.port)

                """
            )
            attachSession(LocalSSHOnlySession(record: connection), to: tab.id)
            attachLocalSSHProcess(to: tab.id, connection: connection, credential: credential)
            updateRemoteFiles([], path: remotePath, tabID: tab.id)
            if shouldAutoConnectSFTPAfterLocalSSH(connection, credential: credential) {
                await connectSFTPForSelectedTab(notifiesOnFailure: false)
            }
            return
        }

        do {
            let session = try await connectWithTimeout(
                record: connection,
                credential: credential,
                suspendsWhileHostKeyPromptIsVisible: true
            )
            connection = markConnectionConnected(connection)
            if persistsNewConnection {
                connections.append(connection)
                await persistConnections()
                if let credential {
                    try? await credentialStore.save(credential, for: connection.id)
                }
            }
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
            if connection.authentication.kind == .password, credential != nil, isSSHAuthenticationFailure(error) {
                try? await credentialStore.delete(for: connection.id)
                connection = markConnectionConnected(connection)
                if persistsNewConnection {
                    connections.append(connection)
                    await persistConnections()
                }
                updateTab(
                    id: tab.id,
                    state: .connected,
                    transcript: """
                    \(t.connectedTo) \(connection.username)@\(connection.host):\(connection.port)

                    """
                )
                attachSession(LocalSSHOnlySession(record: connection), to: tab.id)
                attachLocalSSHProcess(to: tab.id, connection: connection, credential: nil)
                updateRemoteFiles([], path: remotePath, tabID: tab.id)
                showNotification(kind: .warning, message: t.savedPasswordAuthenticationFailed)
                return
            }

            if shouldFallbackToLocalSSHAfterTransportFailure(connection, credential: credential, error: error) {
                connection = markConnectionConnected(connection)
                if persistsNewConnection {
                    connections.append(connection)
                    await persistConnections()
                    if let credential {
                        try? await credentialStore.save(credential, for: connection.id)
                    }
                }
                updateTab(
                    id: tab.id,
                    state: .connected,
                    transcript: """
                    \(t.connectedTo) \(connection.username)@\(connection.host):\(connection.port)

                    """
                )
                attachSession(LocalSSHOnlySession(record: connection), to: tab.id)
                attachLocalSSHProcess(to: tab.id, connection: connection, credential: credential)
                updateRemoteFiles([], path: remotePath, tabID: tab.id)
                await connectSFTPForSelectedTab(notifiesOnFailure: false)
                return
            }

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

    func requiresLocalSSHOnly(_ connection: ConnectionRecord, credential: Credential?) -> Bool {
        connection.requiresLocalSSHOnly
            || connection.authentication.kind == .password
    }

    func shouldAutoConnectSFTPAfterLocalSSH(_ connection: ConnectionRecord, credential: Credential?) -> Bool {
        !connection.requiresLocalSSHOnly
            && connection.authentication.kind == .password
            && credential != nil
    }

    func shouldFallbackToLocalSSHAfterTransportFailure(
        _ connection: ConnectionRecord,
        credential: Credential?,
        error: any Error
    ) -> Bool {
        guard connection.authentication.kind == .password, credential != nil else {
            return false
        }

        let description = String(describing: error)
        return description.contains("No route to host")
            || description.contains("Network is unreachable")
            || description.contains("Connection refused")
            || description.contains("Operation timed out")
    }

    func connectWithTimeout(
        record: ConnectionRecord,
        credential: Credential?,
        suspendsWhileHostKeyPromptIsVisible: Bool = false
    ) async throws -> SSHSessionProviding {
        let timeoutMessage = t.connectionTimedOut(seconds: connectionTimeoutSeconds)
        return try await withThrowingTaskGroup(of: SSHSessionProviding.self) { group in
            group.addTask {
                try await self.sshClient.connect(record: record, credential: credential)
            }
            group.addTask {
                let deadline = Date().addingTimeInterval(self.connectionTimeoutSeconds)
                while true {
                    if Task.isCancelled {
                        throw CancellationError()
                    }

                    if suspendsWhileHostKeyPromptIsVisible, await self.pendingHostKeyPrompt != nil {
                        try await Task.sleep(for: .milliseconds(50))
                        continue
                    }

                    let remaining = deadline.timeIntervalSinceNow
                    guard remaining > 0 else {
                        break
                    }

                    try await Task.sleep(for: .seconds(min(remaining, 0.05)))
                }
                throw SSHConnectionTimeoutError(message: timeoutMessage)
            }

            guard let session = try await group.next() else {
                throw SSHConnectionTimeoutError(message: timeoutMessage)
            }
            group.cancelAll()
            return session
        }
    }

}
