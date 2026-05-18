import Foundation
import Observation
import TermCCore

@Observable
@MainActor
final class AppState {
    static let defaultConnectionStoreURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TermTP", isDirectory: true)
        .appendingPathComponent("connections.json")

    private let sshClient: any SSHClientProviding
    private let credentialStore: any CredentialStoring
    private let sftpService: any SFTPServicing
    private let connectionStore: ConnectionStore
    private let connectionTimeoutSeconds: Double
    let hostKeyTrustStore: AppHostKeyTrustStore

    var isSidebarVisible = true
    var isSFTPDrawerVisible = true
    var terminalFontSize = 11
    var terminalTheme: TerminalTheme {
        didSet {
            defaults.set(terminalTheme.rawValue, forKey: Self.terminalThemeDefaultsKey)
        }
    }
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.languageDefaultsKey)
        }
    }
    var selectedTabID: TerminalTab.ID?
    var tabs: [TerminalTab]
    var pendingTerminalCommands: [TerminalTab.ID: TerminalCommand] = [:]
    private var transferTasks: [TransferRecord.ID: Task<Void, Never>] = [:]
    var connections: [ConnectionRecord]
    var transfers: [TransferRecord]
    var notification: AppNotification?
    var isConnectionFormPresented = false
    var draftAlias = ""
    var draftGroup = ""
    var draftHost = ""
    var draftPort = "22"
    var draftUsername = ""
    var draftPassword = ""
    var draftUsesKey = false
    var draftPrivateKeyPath = ""
    var draftPrivateKeyPassphrase = ""
    var draftTags = ""
    var draftKeepAliveEnabled = false
    var draftKeepAliveInterval = "30"
    var draftKeepAliveMaxCount = "3"
    var draftJumpHost = ""
    var draftDefaultRemotePath = ""
    var draftForwardEnabled = false
    var draftForwardDirection = ConnectionRecord.PortForward.Direction.local
    var draftForwardBindAddress = "127.0.0.1"
    var draftForwardLocalPort = ""
    var draftForwardDestinationHost = ""
    var draftForwardDestinationPort = ""
    var pendingHostKeyPrompt: HostKeyPrompt?
    var remotePath = "."
    var remoteFiles: [RemoteFile] = []
    var filePreview: RemoteFilePreview?
    private var trustedHostKeyRevision = 0

    var t: AppStrings {
        AppStrings(language: language)
    }

    var terminalPalette: TerminalPalette {
        TerminalPalette.palette(for: terminalTheme)
    }

    var terminalFontSizeOptions: [Int] {
        TerminalFont.sizeOptions
    }

    var trustedHostKeys: [AppHostKeyTrustStore.TrustedHostKey] {
        _ = trustedHostKeyRevision
        return hostKeyTrustStore.trustedHostKeys
    }

    private static let languageDefaultsKey = "TermTP.language"
    private static let terminalThemeDefaultsKey = "TermTP.terminalTheme"
    private let defaults: UserDefaults

    init(
        tabs: [TerminalTab] = [.welcome],
        connections: [ConnectionRecord] = [.samplePassword],
        transfers: [TransferRecord] = [],
        language: AppLanguage? = nil,
        terminalTheme: TerminalTheme? = nil,
        defaults: UserDefaults = .standard,
        sshClient: (any SSHClientProviding)? = nil,
        credentialStore: any CredentialStoring = KeychainCredentialStore(),
        sftpService: any SFTPServicing = CitadelSFTPService(),
        connectionStore: ConnectionStore = ConnectionStore(fileURL: AppState.defaultConnectionStoreURL),
        connectionTimeoutSeconds: Double = 10
    ) {
        let hostKeyTrustStore = AppHostKeyTrustStore()
        self.hostKeyTrustStore = hostKeyTrustStore
        self.sshClient = sshClient ?? CitadelSSHClient(
            hostKeyPolicy: .strict,
            hostKeyTrustStore: hostKeyTrustStore
        )
        self.credentialStore = credentialStore
        self.sftpService = sftpService
        self.connectionStore = connectionStore
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
        self.defaults = defaults
        self.tabs = tabs
        self.connections = connections
        self.transfers = transfers
        let storedLanguage = defaults.string(forKey: Self.languageDefaultsKey).flatMap(AppLanguage.init(rawValue:))
        self.language = language ?? storedLanguage ?? AppLanguage.default
        let storedTheme = defaults.string(forKey: Self.terminalThemeDefaultsKey).flatMap(TerminalTheme.init(rawValue:))
        self.terminalTheme = terminalTheme ?? storedTheme ?? TerminalTheme.default
        self.selectedTabID = tabs.first?.id
        hostKeyTrustStore.onPromptChanged = { [weak self] prompt in
            self?.pendingHostKeyPrompt = prompt
        }
    }

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

    var visibleTransfers: [TransferRecord] {
        guard let selectedTabID else {
            return []
        }

        let recentCompletionCutoff = Date().addingTimeInterval(-4)
        return transfers.filter {
            guard $0.sessionID == selectedTabID else {
                return false
            }

            switch $0.state {
            case .completed:
                return ($0.finishedAt ?? $0.updatedAt) >= recentCompletionCutoff
            case .cancelled:
                return false
            case .queued, .running, .failed:
                return true
            }
        }
    }

    func trustPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: true)
    }

    func rejectPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: false)
    }

    func removeTrustedHostKey(hostPort: String) {
        hostKeyTrustStore.removeTrustedKey(hostPort: hostPort)
        trustedHostKeyRevision += 1
    }

    func clearTrustedHostKeys() {
        hostKeyTrustStore.clearTrustedKeys()
        trustedHostKeyRevision += 1
    }

    func showNotification(kind: AppNotification.Kind, message: String) {
        notification = AppNotification(kind: kind, message: message)
    }

    func dismissNotification() {
        notification = nil
    }

    func closeTab(_ id: TerminalTab.ID) async {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        let closedTab = tabs[index]
        tabs.remove(at: index)
        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
            remotePath = tabs[nextIndex].remotePath
            await refreshRemoteFiles()
        }

        try? await closedTab.session?.disconnect()
    }

    func selectTab(_ id: TerminalTab.ID) async {
        guard let tab = tabs.first(where: { $0.id == id }) else {
            return
        }

        selectedTabID = id
        remotePath = tab.remotePath
        await refreshRemoteFiles()
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

    func sendInputToSelectedTab(_ input: String) {
        guard let selectedTabID else {
            return
        }

        pendingTerminalCommands[selectedTabID] = TerminalCommand(text: input)
        appendTranscript(input, to: selectedTabID)
    }

    func clearPendingTerminalCommand(for id: TerminalTab.ID, commandID: TerminalCommand.ID) {
        guard pendingTerminalCommands[id]?.id == commandID else {
            return
        }

        pendingTerminalCommands[id] = nil
    }

    func renameTab(_ id: TerminalTab.ID, to title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedTitle.isEmpty,
            let index = tabs.firstIndex(where: { $0.id == id })
        else {
            return
        }

        tabs[index].title = trimmedTitle
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleSFTPDrawer() {
        isSFTPDrawerVisible.toggle()
    }

    func increaseTerminalFontSize() {
        terminalFontSize = min(TerminalFont.sizeOptions.last ?? terminalFontSize, terminalFontSize + 1)
    }

    func decreaseTerminalFontSize() {
        terminalFontSize = max(TerminalFont.sizeOptions.first ?? terminalFontSize, terminalFontSize - 1)
    }

    func refreshRemoteFiles() async {
        saveRemotePathForSelectedTab()

        guard
            let selectedTabID,
            let session = selectedSession
        else {
            remoteFiles = []
            return
        }

        await refreshRemoteFiles(tabID: selectedTabID, path: remotePath, session: session)
    }

    private func refreshRemoteFiles(
        tabID: TerminalTab.ID,
        path: String,
        session: SSHSessionProviding
    ) async {
        do {
            let files = try await sftpService.list(path: path, session: session)
            updateRemoteFiles(files, path: path, tabID: tabID)
        } catch SFTPServiceError.unsupportedSession {
            updateRemoteFiles([], path: path, tabID: tabID)
            showNotification(kind: .warning, message: t.sftpUnsupportedForConnection)
        } catch {
            updateRemoteFiles([], path: path, tabID: tabID)
            showNotification(kind: .error, message: t.sftpRefreshFailed(String(describing: error)))
        }
    }

    func openRemoteDirectory(_ file: RemoteFile) async {
        guard file.kind == .directory else {
            return
        }

        remotePath = file.path
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func openRemoteParentDirectory() async {
        guard remotePath != "." && remotePath != "/" else {
            return
        }

        let parent = URL(fileURLWithPath: remotePath).deletingLastPathComponent().path
        remotePath = parent == "/" || parent.isEmpty ? "." : parent
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func openRemotePath(_ path: String) async {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return
        }

        remotePath = trimmedPath
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func uploadFile(localPath: String) async {
        saveRemotePathForSelectedTab()
        await uploadFile(localPath: localPath, remoteDirectoryPath: remotePath)
    }

    func uploadFile(localPath: String, toRemoteDirectory directory: RemoteFile) async {
        guard directory.kind == .directory else {
            return
        }

        saveRemotePathForSelectedTab()
        await uploadFile(localPath: localPath, remoteDirectoryPath: directory.path)
    }

    func createRemoteDirectory(named name: String) async {
        saveRemotePathForSelectedTab()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let context = selectedSFTPContext,
            !trimmedName.isEmpty
        else {
            return
        }

        let path = joinedRemotePath(directory: context.path, name: trimmedName)
        do {
            try await sftpService.makeDirectory(remotePath: path, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .upload,
                localPath: "",
                remotePath: path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func deleteRemoteFile(_ file: RemoteFile) async {
        saveRemotePathForSelectedTab()
        guard let context = selectedSFTPContext else {
            return
        }

        do {
            try await sftpService.delete(remotePath: file.path, kind: file.kind, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .download,
                localPath: "",
                remotePath: file.path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func renameRemoteFile(_ file: RemoteFile, to newName: String) async {
        saveRemotePathForSelectedTab()
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let context = selectedSFTPContext,
            !trimmedName.isEmpty
        else {
            return
        }

        let parent = URL(fileURLWithPath: file.path).deletingLastPathComponent().path
        let newPath = joinedRemotePath(directory: parent == "/" ? "/" : parent, name: trimmedName)
        do {
            try await sftpService.rename(remotePath: file.path, to: newPath, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .download,
                localPath: "",
                remotePath: file.path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func previewRemoteFile(_ file: RemoteFile) async {
        guard file.kind == .file, let context = selectedSFTPContext else {
            return
        }

        do {
            let text = try await sftpService.previewText(
                remotePath: file.path,
                byteLimit: 64 * 1024,
                session: context.session
            )
            filePreview = RemoteFilePreview(file: file, text: text)
        } catch {
            showNotification(kind: .error, message: t.previewFailed(String(describing: error)))
        }
    }

    func dismissFilePreview() {
        filePreview = nil
    }

    func changeRemoteFilePermissions(_ file: RemoteFile, modeText: String) async {
        saveRemotePathForSelectedTab()
        guard let context = selectedSFTPContext else {
            return
        }

        let trimmedMode = modeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedMode.isEmpty,
            let mode = UInt32(trimmedMode, radix: 8)
        else {
            showNotification(kind: .error, message: t.invalidPermissions)
            return
        }

        do {
            try await sftpService.changePermissions(remotePath: file.path, permissions: mode, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            showNotification(kind: .error, message: t.permissionsChangeFailed(String(describing: error)))
        }
    }

    private func uploadFile(localPath: String, remoteDirectoryPath: String) async {
        guard let context = selectedSFTPContext else {
            recordFailedTransfer(
                direction: .upload,
                localPath: localPath,
                remotePath: remoteDirectoryPath,
                message: t.noActiveSSHSession
            )
            return
        }

        let remoteFilePath = joinedRemotePath(
            directory: remoteDirectoryPath,
            name: URL(fileURLWithPath: localPath).lastPathComponent
        )
        let transfer = appendTransfer(
            direction: .upload,
            localPath: localPath,
            remotePath: remoteFilePath,
            sessionID: context.tabID
        )

        await runTrackedTransfer(transfer.id) {
            await self.runUploadTransfer(
                transfer.id,
                localPath: localPath,
                remotePath: remoteFilePath,
                context: context
            )
        }
    }

    private func joinedRemotePath(directory: String, name: String) -> String {
        let trimmedDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDirectory.isEmpty || trimmedDirectory == "." {
            return name
        }

        if trimmedDirectory == "/" {
            return "/\(name)"
        }

        var normalizedDirectory = trimmedDirectory
        while normalizedDirectory.hasSuffix("/") {
            normalizedDirectory.removeLast()
        }
        return "\(normalizedDirectory)/\(name)"
    }

    func downloadFile(remoteFile: RemoteFile, localPath: String) async {
        guard let context = selectedSFTPContext else {
            recordFailedTransfer(
                direction: .download,
                localPath: localPath,
                remotePath: remoteFile.path,
                message: t.noActiveSSHSession
            )
            return
        }

        let resumeOffset = localFileSize(at: localPath)
        let transfer = appendTransfer(
            direction: .download,
            localPath: localPath,
            remotePath: remoteFile.path,
            sessionID: context.tabID,
            bytesCompleted: resumeOffset,
            totalBytes: remoteFile.size
        )

        await runTrackedTransfer(transfer.id) {
            await self.runDownloadTransfer(
                transfer.id,
                remotePath: remoteFile.path,
                localPath: localPath,
                totalBytes: remoteFile.size,
                session: context.session
            )
        }
    }

    func cancelTransfer(_ id: TransferRecord.ID) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard transfers[index].state == .running || transfers[index].state == .queued else {
            return
        }

        transferTasks[id]?.cancel()
        transferTasks[id] = nil
        transfers[index].state = .cancelled
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = Date()
    }

    func clearFinishedTransfersForSelectedTab() {
        guard let selectedTabID else {
            return
        }

        transfers.removeAll {
            $0.sessionID == selectedTabID && ($0.state == .completed || $0.state == .cancelled)
        }
    }

    func retryTransfer(_ id: TransferRecord.ID) async {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        let transfer = transfers[index]
        guard transfer.state == .failed || transfer.state == .cancelled else {
            return
        }

        transfers[index].state = .running
        transfers[index].errorMessage = nil
        transfers[index].bytesCompleted = 0
        transfers[index].createdAt = Date()
        transfers[index].updatedAt = transfers[index].createdAt
        transfers[index].finishedAt = nil

        guard let context = sftpContext(for: transfer.sessionID) else {
            failTransfer(id, message: t.noActiveSSHSession)
            return
        }

        switch transfer.direction {
        case .download:
            await runTrackedTransfer(id) {
                await self.runDownloadTransfer(
                    id,
                    remotePath: transfer.remotePath,
                    localPath: transfer.localPath,
                    totalBytes: transfer.totalBytes,
                    session: context.session
                )
            }
        case .upload:
            await runTrackedTransfer(id) {
                await self.runUploadTransfer(
                    id,
                    localPath: transfer.localPath,
                    remotePath: transfer.remotePath,
                    context: context
                )
            }
        }
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

    private func connect(_ connection: ConnectionRecord, credential: Credential?) async {
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

    private func connectWithTimeout(
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

    private func makeDraftConnection() -> ConnectionRecord? {
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

    private func parseTags(_ value: String) -> [String] {
        value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func importKey(for connection: ConnectionRecord) -> String {
        "\(connection.host):\(connection.port):\(connection.username):\(connection.alias)"
    }

    private func makeDraftPortForwards(
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

    private func markConnectionUsed(_ connection: ConnectionRecord) -> ConnectionRecord {
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

    private func updateTab(id: TerminalTab.ID, state: SSHSessionState, transcript: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].state = state
        tabs[index].transcript = transcript
    }

    private func appendTranscript(_ transcript: String, to id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].transcript += transcript
    }

    private func attachLocalSSHProcess(to id: TerminalTab.ID, connection: ConnectionRecord, credential: Credential?) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].localProcess = .ssh(connection, credential: credential)
    }

    private var selectedSession: SSHSessionProviding? {
        guard
            let selectedTabID,
            let tab = tabs.first(where: { $0.id == selectedTabID })
        else {
            return nil
        }

        return tab.session
    }

    private var selectedSFTPContext: SFTPContext? {
        guard
            let selectedTabID
        else {
            return nil
        }

        return sftpContext(for: selectedTabID)
    }

    private func sftpContext(for tabID: TerminalTab.ID) -> SFTPContext? {
        guard
            let tab = tabs.first(where: { $0.id == tabID }),
            let session = tab.session
        else {
            return nil
        }

        return SFTPContext(tabID: tabID, path: tab.remotePath, session: session)
    }

    private func attachSession(_ session: SSHSessionProviding, to id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].session = session
    }

    private func saveRemotePathForSelectedTab() {
        guard
            let selectedTabID,
            let index = tabs.firstIndex(where: { $0.id == selectedTabID })
        else {
            return
        }

        tabs[index].remotePath = remotePath
    }

    private func setRemotePath(_ path: String, for tabID: TerminalTab.ID) {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextPath = normalizedPath.isEmpty ? "." : normalizedPath
        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].remotePath = nextPath
        }
        if selectedTabID == tabID {
            remotePath = nextPath
        }
    }

    private func updateRemoteFiles(_ files: [RemoteFile], path: String, tabID: TerminalTab.ID) {
        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].remotePath = path
        }

        if selectedTabID == tabID {
            remotePath = path
            remoteFiles = files
        }
    }

    private func appendTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        sessionID: TerminalTab.ID? = nil,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0
    ) -> TransferRecord {
        let transfer = TransferRecord(
            sessionID: sessionID ?? selectedTabID ?? UUID(),
            direction: direction,
            localPath: localPath,
            remotePath: remotePath,
            bytesCompleted: bytesCompleted,
            totalBytes: totalBytes,
            state: .running
        )
        transfers.append(transfer)
        return transfer
    }

    private func runTrackedTransfer(
        _ id: TransferRecord.ID,
        operation: @escaping @MainActor () async -> Void
    ) async {
        let task = Task { @MainActor in
            await operation()
        }
        transferTasks[id] = task
        await task.value
        transferTasks[id] = nil
    }

    private func runUploadTransfer(
        _ id: TransferRecord.ID,
        localPath: String,
        remotePath: String,
        context: SFTPContext
    ) async {
        do {
            try Task.checkCancellation()
            try await sftpService.upload(localPath: localPath, remotePath: remotePath, session: context.session)
            try Task.checkCancellation()
            completeTransfer(id)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch is CancellationError {
            cancelTransfer(id)
        } catch {
            failTransfer(id, message: String(describing: error))
        }
    }

    private func runDownloadTransfer(
        _ id: TransferRecord.ID,
        remotePath: String,
        localPath: String,
        totalBytes: Int64,
        session: SSHSessionProviding
    ) async {
        let resumeOffset = localFileSize(at: localPath)
        updateTransferProgress(id, bytesCompleted: resumeOffset, totalBytes: totalBytes)

        do {
            try Task.checkCancellation()
            try await sftpService.download(
                remotePath: remotePath,
                localPath: localPath,
                resumeFrom: resumeOffset,
                progress: { [weak self] bytesCompleted, totalBytes in
                    await self?.updateTransferProgress(
                        id,
                        bytesCompleted: bytesCompleted,
                        totalBytes: totalBytes
                    )
                },
                session: session
            )
            try Task.checkCancellation()
            completeTransfer(id)
        } catch is CancellationError {
            cancelTransfer(id)
        } catch {
            failTransfer(id, message: String(describing: error))
        }
    }

    private func recordFailedTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        sessionID: TerminalTab.ID? = nil,
        message: String
    ) {
        transfers.append(TransferRecord(
            sessionID: sessionID ?? selectedTabID ?? UUID(),
            direction: direction,
            localPath: localPath,
            remotePath: remotePath,
            state: .failed,
            errorMessage: message
        ))
    }

    private func completeTransfer(_ id: TransferRecord.ID) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].bytesCompleted = max(transfers[index].bytesCompleted, transfers[index].totalBytes)
        transfers[index].state = .completed
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = transfers[index].updatedAt
    }

    private func updateTransferProgress(
        _ id: TransferRecord.ID,
        bytesCompleted: Int64,
        totalBytes: Int64
    ) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].bytesCompleted = bytesCompleted
        transfers[index].totalBytes = totalBytes
        transfers[index].updatedAt = Date()
    }

    private func failTransfer(_ id: TransferRecord.ID, message: String) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].state = .failed
        transfers[index].errorMessage = message
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = nil
    }

    private func localFileSize(at path: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int64 ?? 0
    }
}

private struct SFTPContext {
    var tabID: TerminalTab.ID
    var path: String
    var session: SSHSessionProviding
}
