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
    var selectedTabID: TerminalTab.ID?
    var tabs: [TerminalTab]
    var connections: [ConnectionRecord]
    var transfers: [TransferRecord]
    var isConnectionFormPresented = false
    var draftAlias = ""
    var draftHost = ""
    var draftPort = "22"
    var draftUsername = ""
    var draftPassword = ""
    var draftUsesKey = false
    var draftPrivateKeyPath = ""
    var draftPrivateKeyPassphrase = ""
    var pendingHostKeyPrompt: HostKeyPrompt?
    var remotePath = "."
    var remoteFiles: [RemoteFile] = []

    init(
        tabs: [TerminalTab] = [.welcome],
        connections: [ConnectionRecord] = [.samplePassword],
        transfers: [TransferRecord] = [],
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
        self.tabs = tabs
        self.connections = connections
        self.transfers = transfers
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

    func trustPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: true)
    }

    func rejectPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: false)
    }

    func closeTab(_ id: TerminalTab.ID) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs.remove(at: index)
        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
            remotePath = tabs[nextIndex].remotePath
            remoteFiles = []
        }
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

    func sendInputToSelectedTab(_ input: String) {
        guard let selectedTabID else {
            return
        }

        appendTranscript(input, to: selectedTabID)
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleSFTPDrawer() {
        isSFTPDrawerVisible.toggle()
    }

    func refreshRemoteFiles() async {
        saveRemotePathForSelectedTab()

        guard let session = selectedSession else {
            remoteFiles = []
            return
        }

        do {
            remoteFiles = try await sftpService.list(path: remotePath, session: session)
        } catch {
            remoteFiles = []
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
        await uploadFile(localPath: localPath, remoteDirectoryPath: remotePath)
    }

    func uploadFile(localPath: String, toRemoteDirectory directory: RemoteFile) async {
        guard directory.kind == .directory else {
            return
        }

        await uploadFile(localPath: localPath, remoteDirectoryPath: directory.path)
    }

    private func uploadFile(localPath: String, remoteDirectoryPath: String) async {
        guard let session = selectedSession else {
            recordFailedTransfer(
                direction: .upload,
                localPath: localPath,
                remotePath: remoteDirectoryPath,
                message: "No active SSH session"
            )
            return
        }

        let remoteFilePath = "\(remoteDirectoryPath)/\(URL(fileURLWithPath: localPath).lastPathComponent)"
        let transfer = appendTransfer(direction: .upload, localPath: localPath, remotePath: remoteFilePath)

        do {
            try await sftpService.upload(localPath: localPath, remotePath: remoteFilePath, session: session)
            completeTransfer(transfer.id)
            remoteFiles = (try? await sftpService.list(path: remotePath, session: session)) ?? remoteFiles
        } catch {
            failTransfer(transfer.id, message: String(describing: error))
        }
    }

    func downloadFile(remoteFile: RemoteFile, localPath: String) async {
        guard let session = selectedSession else {
            recordFailedTransfer(
                direction: .download,
                localPath: localPath,
                remotePath: remoteFile.path,
                message: "No active SSH session"
            )
            return
        }

        let resumeOffset = localFileSize(at: localPath)
        let transfer = appendTransfer(
            direction: .download,
            localPath: localPath,
            remotePath: remoteFile.path,
            bytesCompleted: resumeOffset,
            totalBytes: remoteFile.size
        )

        do {
            try await sftpService.download(
                remotePath: remoteFile.path,
                localPath: localPath,
                resumeFrom: resumeOffset,
                progress: { [weak self] bytesCompleted, totalBytes in
                    await self?.updateTransferProgress(
                        transfer.id,
                        bytesCompleted: bytesCompleted,
                        totalBytes: totalBytes
                    )
                },
                session: session
            )
            completeTransfer(transfer.id)
        } catch {
            failTransfer(transfer.id, message: String(describing: error))
        }
    }

    func beginNewConnection() {
        draftAlias = ""
        draftHost = ""
        draftPort = "22"
        draftUsername = ""
        draftPassword = ""
        draftUsesKey = false
        draftPrivateKeyPath = ""
        draftPrivateKeyPassphrase = ""
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
        let tab = TerminalTab(
            title: connection.alias,
            state: .connecting,
            transcript: "Connecting to \(connection.username)@\(connection.host):\(connection.port)...\n"
        )
        tabs.append(tab)
        selectedTabID = tab.id

        do {
            let session = try await connectWithTimeout(record: connection, credential: credential)
            updateTab(
                id: tab.id,
                state: .connected,
                transcript: """
                Connected to \(connection.username)@\(connection.host):\(connection.port)

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
                Failed to connect to \(connection.username)@\(connection.host):\(connection.port)
                \(message)

                """
            )
        }
    }

    private func connectWithTimeout(
        record: ConnectionRecord,
        credential: Credential?
    ) async throws -> SSHSessionProviding {
        try await withThrowingTaskGroup(of: SSHSessionProviding.self) { group in
            group.addTask {
                try await self.sshClient.connect(record: record, credential: credential)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeoutSeconds))
                throw SSHConnectionTimeoutError(seconds: self.connectionTimeoutSeconds)
            }

            guard let session = try await group.next() else {
                throw SSHConnectionTimeoutError(seconds: self.connectionTimeoutSeconds)
            }
            group.cancelAll()
            return session
        }
    }

    private func makeDraftConnection() -> ConnectionRecord? {
        let alias = draftAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let port = UInt16(draftPort.trimmingCharacters(in: .whitespacesAndNewlines)),
            port > 0,
            !host.isEmpty,
            !username.isEmpty,
            !draftUsesKey || !privateKeyPath.isEmpty
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
            authentication: authentication
        )
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

    private func appendTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0
    ) -> TransferRecord {
        let transfer = TransferRecord(
            sessionID: selectedTabID ?? UUID(),
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

    private func recordFailedTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        message: String
    ) {
        transfers.append(TransferRecord(
            sessionID: selectedTabID ?? UUID(),
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

        transfers[index].bytesCompleted = max(transfers[index].bytesCompleted, transfers[index].totalBytes)
        transfers[index].state = .completed
    }

    private func updateTransferProgress(
        _ id: TransferRecord.ID,
        bytesCompleted: Int64,
        totalBytes: Int64
    ) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        transfers[index].bytesCompleted = bytesCompleted
        transfers[index].totalBytes = totalBytes
    }

    private func failTransfer(_ id: TransferRecord.ID, message: String) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        transfers[index].state = .failed
        transfers[index].errorMessage = message
    }

    private func localFileSize(at path: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int64 ?? 0
    }
}

@MainActor
final class AppHostKeyTrustStore: HostKeyTrusting, @unchecked Sendable {
    private let defaults: UserDefaults
    private let defaultsKey = "TermTP.trustedHostKeys"
    private var trustedKeys: [String: String]
    private var pendingContinuation: CheckedContinuation<Bool, Never>?
    var pendingPrompt: HostKeyPrompt?
    var onPromptChanged: ((HostKeyPrompt?) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.trustedKeys = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    func trustedKey(host: String, port: UInt16) async -> String? {
        trustedKeys[key(for: host, port: port)]
    }

    func saveTrustedKey(_ key: String, host: String, port: UInt16) async throws {
        trustedKeys[self.key(for: host, port: port)] = key
        defaults.set(trustedKeys, forKey: defaultsKey)
    }

    func requestTrust(for prompt: HostKeyPrompt) async -> Bool {
        pendingPrompt = prompt
        onPromptChanged?(prompt)
        return await withCheckedContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    func resolvePendingPrompt(trusted: Bool) {
        if trusted, let pendingPrompt {
            trustedKeys[key(for: pendingPrompt.host, port: pendingPrompt.port)] = pendingPrompt.key
            defaults.set(trustedKeys, forKey: defaultsKey)
        }

        pendingPrompt = nil
        onPromptChanged?(nil)
        pendingContinuation?.resume(returning: trusted)
        pendingContinuation = nil
    }

    private func key(for host: String, port: UInt16) -> String {
        "\(host):\(port)"
    }
}

struct SSHConnectionTimeoutError: Error, Equatable, CustomStringConvertible {
    var seconds: Double

    var description: String {
        "Connection timed out after \(seconds) seconds"
    }
}

struct TerminalTab: Identifiable, Equatable {
    var id: UUID
    var title: String
    var state: SSHSessionState
    var transcript: String
    var remotePath: String
    var localProcess: TerminalLocalProcess?
    var session: SSHSessionProviding?

    init(
        id: UUID = UUID(),
        title: String,
        state: SSHSessionState,
        transcript: String,
        remotePath: String = ".",
        localProcess: TerminalLocalProcess? = nil,
        session: SSHSessionProviding? = nil
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.transcript = transcript
        self.remotePath = remotePath
        self.localProcess = localProcess
        self.session = session
    }

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.state == rhs.state
            && lhs.transcript == rhs.transcript
            && lhs.remotePath == rhs.remotePath
            && lhs.localProcess == rhs.localProcess
    }
}

enum TerminalLocalProcess: Equatable {
    case ssh(ConnectionRecord, credential: Credential?)
}

extension TerminalTab {
    static let welcome = TerminalTab(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Welcome",
        state: .disconnected,
        transcript: """
        Welcome to TermTP

        Select a connection from the sidebar to start an SSH session.
        """
    )
}
