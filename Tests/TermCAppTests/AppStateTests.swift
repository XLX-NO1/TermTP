import AppKit
import Testing
import TermCCore
@testable import TermCApp

@MainActor
@Test func terminalFontSizeOptionsOnlyIncludeVisiblyChangingSizes() {
    let state = AppState(connections: [])

    #expect(state.terminalFontSizeOptions == [9, 11, 13, 15, 17])
}

@MainActor
@Test func showNotificationStoresUserVisibleMessageAndDismissesIt() {
    let state = AppState(connections: [], language: .zhHans)

    state.showNotification(kind: .error, message: "导入失败")

    #expect(state.notification?.kind == .error)
    #expect(state.notification?.message == "导入失败")

    state.dismissNotification()

    #expect(state.notification == nil)
}

@MainActor
@Test func refreshRemoteFilesReportsUnsupportedSFTPToUser() async {
    let tab = TerminalTab(title: "Jump", state: .connected, transcript: "", session: UnsupportedSFTPSession())
    let state = AppState(tabs: [tab], connections: [], language: .zhHans)
    state.selectedTabID = tab.id

    await state.refreshRemoteFiles()

    #expect(state.remoteFiles.isEmpty)
    #expect(state.notification?.kind == .warning)
    #expect(state.notification?.message == "当前连接暂不支持 SFTP 文件管理")
}

@MainActor
@Test func menuBarTemplateImageFallsBackWhenResourceIsMissing() {
    let image = MenuBarController.makeMenuBarTemplateImage()

    #expect(image.size == .init(width: 18, height: 18))
    #expect(image.isTemplate)
}

@MainActor
@Test func menuBarTemplateImageNormalizerShrinksLargeResourceImages() {
    let image = NSImage(size: .init(width: 64, height: 64))

    let normalized = MenuBarController.normalizedMenuBarTemplateImage(image)

    #expect(normalized.size == .init(width: 18, height: 18))
    #expect(normalized.isTemplate)
}

@MainActor
@Test func saveDraftConnectionRejectsPortZero() {
    let state = AppState(connections: [])
    state.draftHost = "example.com"
    state.draftPort = "0"
    state.draftUsername = "me"

    state.saveDraftConnection()

    #expect(state.connections.isEmpty)
}

@MainActor
@Test func saveDraftConnectionRejectsEmptyPrivateKeyPath() {
    let state = AppState(connections: [])
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "me"
    state.draftUsesKey = true
    state.draftPrivateKeyPath = " \n "

    state.saveDraftConnection()

    #expect(state.connections.isEmpty)
}

@MainActor
@Test func saveDraftConnectionStoresConnectionGroup() {
    let state = AppState(connections: [])
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "me"
    state.draftPassword = "secret"
    state.draftGroup = " 生产 "

    state.saveDraftConnection()

    #expect(state.connections.first?.group == "生产")
}

@MainActor
@Test func beginNewConnectionLeavesUsernameEmpty() {
    let state = AppState(connections: [])

    state.beginNewConnection()

    #expect(state.draftUsername == "")
}

@MainActor
@Test func connectDraftConnectionCreatesConnectedTabAndLoadsRemoteFiles() async {
    let sftpService = RecordingSFTPService(filesByPath: [
        "/var/www": [RemoteFile(name: "readme.txt", path: "/var/www/readme.txt", kind: .file, size: 12)]
    ])
    let state = AppState(connections: [], sshClient: FakeSSHClient(), sftpService: sftpService)
    state.draftAlias = "Prod"
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = "secret"
    state.draftDefaultRemotePath = " /var/www "

    await state.connectDraftConnection()

    #expect(state.connections.count == 1)
    #expect(state.tabs.count == 2)
    #expect(state.tabs.last?.title == "Prod")
    #expect(state.tabs.last?.state == .connected)
    #expect(state.tabs.last?.transcript.contains("Connected to deploy@example.com:22") == true)
    #expect(state.tabs.last?.localProcess == .ssh(state.connections[0], credential: .password("secret")))
    #expect(state.selectedTabID == state.tabs.last?.id)
    #expect(state.connections[0].defaultRemotePath == "/var/www")
    #expect(state.remotePath == "/var/www")
    #expect(state.remoteFiles == [RemoteFile(name: "readme.txt", path: "/var/www/readme.txt", kind: .file, size: 12)])
    #expect(await sftpService.listedPaths == ["/var/www"])
}

@MainActor
@Test func jumpHostConnectionStartsLocalSSHWithoutCitadelPreflight() async {
    let state = AppState(
        connections: [],
        sshClient: FailingSSHClient(),
        credentialStore: InMemoryCredentialStore(),
        sftpService: RecordingSFTPService(filesByPath: [:])
    )
    state.draftAlias = "Behind Bastion"
    state.draftHost = "private.example.com"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = "secret"
    state.draftJumpHost = "jump.example.com"

    await state.connectDraftConnection()

    let connection = state.connections[0]

    #expect(state.tabs.last?.state == .connected)
    #expect(state.tabs.last?.localProcess == .ssh(connection, credential: .password("secret")))
    #expect(state.remoteFiles.isEmpty)
}

@MainActor
@Test func trustedHostKeyIsRememberedForNextConnection() async {
    let state = AppState(connections: [])
    let prompt = HostKeyPrompt(host: "example.com", port: 22, key: "ssh-ed25519 AAAATEST", fingerprint: "SHA256:test")

    Task {
        _ = await state.hostKeyTrustStore.requestTrust(for: prompt)
    }
    await Task.yield()
    state.trustPendingHostKey()

    #expect(await state.hostKeyTrustStore.trustedKey(host: "example.com", port: 22) == "ssh-ed25519 AAAATEST")
}

@MainActor
@Test func connectDraftConnectionFailsAfterTimeout() async {
    let state = AppState(
        connections: [],
        language: .zhHans,
        sshClient: HangingSSHClient(),
        connectionTimeoutSeconds: 0.01
    )
    state.draftAlias = "Slow"
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = "secret"

    await state.connectDraftConnection()

    #expect(state.tabs.last?.state == .failed("连接超时，已等待 0.01 秒"))
    #expect(state.tabs.last?.transcript.contains("连接超时，已等待 0.01 秒") == true)
}

@MainActor
@Test func refreshRemoteFilesListsCurrentRemotePathThroughSFTP() async {
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(
            title: "Connected",
            state: .connected,
            transcript: "",
            session: FakeSSHSession(record: .samplePassword)
        )],
        connections: [],
        sftpService: service
    )
    state.remotePath = "/srv/app"
    state.selectedTabID = state.tabs[0].id

    try? await service.makeDirectory(remotePath: "/srv", session: state.tabs[0].session!)
    try? await service.makeDirectory(remotePath: "/srv/app", session: state.tabs[0].session!)
    try? await service.upload(localPath: "/tmp/release.tgz", remotePath: "/srv/app/release.tgz", session: state.tabs[0].session!)
    try? await service.makeDirectory(remotePath: "/srv/app/logs", session: state.tabs[0].session!)

    await state.refreshRemoteFiles()

    #expect(state.remoteFiles == [
        RemoteFile(name: "logs", path: "/srv/app/logs", kind: .directory, size: 0),
        RemoteFile(name: "release.tgz", path: "/srv/app/release.tgz", kind: .file, size: 1)
    ])
}

@MainActor
@Test func selectingTabRestoresThatTabsRemotePathAndFiles() async {
    let firstSession = FakeSSHSession(record: .samplePassword)
    let secondSession = FakeSSHSession(record: ConnectionRecord(
        alias: "Logs",
        host: "logs.example.com",
        username: "deploy",
        authentication: .password
    ))
    let first = TerminalTab(title: "First", state: .connected, transcript: "", session: firstSession)
    let second = TerminalTab(title: "Second", state: .connected, transcript: "", session: secondSession)
    let service = FakeSFTPService()
    let state = AppState(tabs: [first, second], connections: [], sftpService: service)
    state.selectedTabID = first.id

    try? await service.makeDirectory(remotePath: "/srv", session: firstSession)
    try? await service.makeDirectory(remotePath: "/srv/app", session: firstSession)
    try? await service.upload(localPath: "/tmp/app.txt", remotePath: "/srv/app/app.txt", session: firstSession)
    try? await service.makeDirectory(remotePath: "/var", session: secondSession)
    try? await service.makeDirectory(remotePath: "/var/log", session: secondSession)
    try? await service.upload(localPath: "/tmp/system.log", remotePath: "/var/log/system.log", session: secondSession)

    await state.openRemotePath("/srv/app")
    await state.selectTab(second.id)
    await state.openRemotePath("/var/log")
    await state.selectTab(first.id)

    #expect(state.remotePath == "/srv/app")
    #expect(state.remoteFiles == [
        RemoteFile(name: "app.txt", path: "/srv/app/app.txt", kind: .file, size: 1)
    ])

    await state.selectTab(second.id)

    #expect(state.remotePath == "/var/log")
    #expect(state.remoteFiles == [
        RemoteFile(name: "system.log", path: "/var/log/system.log", kind: .file, size: 1)
    ])
}

@MainActor
@Test func openRemoteDirectoryChangesPathAndListsChildren() async {
    let service = FakeSFTPService()
    let session = FakeSSHSession(record: .samplePassword)
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id

    try? await service.upload(localPath: "/tmp/app.log", remotePath: "/var/www/logs/app.log", session: session)

    await state.openRemoteDirectory(RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0))

    #expect(state.remotePath == "/var/www/logs")
    #expect(state.remoteFiles == [
        RemoteFile(name: "app.log", path: "/var/www/logs/app.log", kind: .file, size: 1)
    ])
}

@MainActor
@Test func openRemoteParentDirectoryReturnsToParentPath() async {
    let service = FakeSFTPService()
    let session = FakeSSHSession(record: .samplePassword)
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/var/www/logs"

    await state.openRemoteParentDirectory()

    #expect(state.remotePath == "/var/www")
}

@MainActor
@Test func openRemotePathUpdatesPathAndListsChildren() async {
    let service = FakeSFTPService()
    let session = FakeSSHSession(record: .samplePassword)
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    try? await service.makeDirectory(remotePath: "/var/www/cache", session: session)
    try? await service.upload(localPath: "/tmp/data.json", remotePath: "/var/www/cache/data.json", session: session)

    await state.openRemotePath(" /var/www/cache ")

    #expect(state.remotePath == "/var/www/cache")
    #expect(state.remoteFiles == [
        RemoteFile(name: "data.json", path: "/var/www/cache/data.json", kind: .file, size: 1)
    ])
}

@MainActor
@Test func closeTabSelectsNeighborAndKeepsAtLeastOneTab() async {
    let first = TerminalTab(title: "First", state: .connected, transcript: "")
    let second = TerminalTab(title: "Second", state: .connected, transcript: "")
    let state = AppState(tabs: [first, second], connections: [])
    state.selectedTabID = second.id

    await state.closeTab(second.id)

    #expect(state.tabs == [first])
    #expect(state.selectedTabID == first.id)

    await state.closeTab(first.id)

    #expect(state.tabs == [first])
    #expect(state.selectedTabID == first.id)
}

@MainActor
@Test func closingSelectedTabRefreshesNeighborRemoteFiles() async {
    let firstSession = FakeSSHSession(record: .samplePassword)
    let secondSession = FakeSSHSession(record: ConnectionRecord(
        alias: "Second",
        host: "second.example.com",
        username: "deploy",
        authentication: .password
    ))
    let first = TerminalTab(
        title: "First",
        state: .connected,
        transcript: "",
        remotePath: "/srv/app",
        session: firstSession
    )
    let second = TerminalTab(
        title: "Second",
        state: .connected,
        transcript: "",
        remotePath: "/var/log",
        session: secondSession
    )
    let service = FakeSFTPService()
    let state = AppState(tabs: [first, second], connections: [], sftpService: service)
    state.selectedTabID = second.id
    state.remotePath = second.remotePath

    try? await service.makeDirectory(remotePath: "/srv", session: firstSession)
    try? await service.makeDirectory(remotePath: "/srv/app", session: firstSession)
    try? await service.upload(localPath: "/tmp/app.txt", remotePath: "/srv/app/app.txt", session: firstSession)

    await state.closeTab(second.id)

    #expect(state.selectedTabID == first.id)
    #expect(state.remotePath == "/srv/app")
    #expect(state.remoteFiles == [
        RemoteFile(name: "app.txt", path: "/srv/app/app.txt", kind: .file, size: 1)
    ])
}

@MainActor
@Test func clearHistoryKeepsFavorites() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    let history = ConnectionRecord(
        alias: "History",
        host: "history.example.com",
        username: "deploy",
        authentication: .password
    )
    let state = AppState(connections: [favorite, history])

    state.clearHistory()

    #expect(state.connections == [favorite])
}

@MainActor
@Test func loadAndPersistConnectionsKeepsHistoryAndFavoritesAcrossLaunches() async {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let store = ConnectionStore(fileURL: url)
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true

    let firstLaunch = AppState(connections: [], connectionStore: store)
    firstLaunch.connections = [favorite]
    await firstLaunch.persistConnections()

    let secondLaunch = AppState(connections: [], connectionStore: store)
    await secondLaunch.loadConnections()

    #expect(secondLaunch.connections == [favorite])
    #expect(secondLaunch.favoriteConnections == [favorite])
}

@MainActor
@Test func deleteConnectionRemovesMatchingConnection() {
    let first = ConnectionRecord.samplePassword
    let second = ConnectionRecord(
        alias: "Delete Me",
        host: "delete.example.com",
        username: "deploy",
        authentication: .password
    )
    let state = AppState(connections: [first, second])

    state.deleteConnection(second.id)

    #expect(state.connections == [first])
}

@MainActor
@Test func deleteHistoryConnectionDoesNotDeleteFavoriteConnection() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    let state = AppState(connections: [favorite])

    state.deleteHistoryConnection(favorite.id)

    #expect(state.connections == [favorite])
}

@MainActor
@Test func toggleFavoriteUpdatesConnection() {
    let connection = ConnectionRecord.samplePassword
    let state = AppState(connections: [connection])

    state.toggleFavorite(connection.id)

    #expect(state.connections.first?.isFavorite == true)

    state.toggleFavorite(connection.id)

    #expect(state.connections.first?.isFavorite == false)
}

@MainActor
@Test func connectionGroupsAreSortedAndIgnoreEmptyValues() {
    let state = AppState(connections: [
        ConnectionRecord(alias: "B", host: "b.example.com", username: "me", authentication: .password, group: "生产"),
        ConnectionRecord(alias: "A", host: "a.example.com", username: "me", authentication: .password, group: "测试"),
        ConnectionRecord(alias: "None", host: "n.example.com", username: "me", authentication: .password)
    ])

    #expect(state.connectionGroups == ["测试", "生产"])
}

@MainActor
@Test func historyConnectionsExcludeFavorites() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    let history = ConnectionRecord(
        alias: "History",
        host: "history.example.com",
        username: "deploy",
        authentication: .password
    )
    let state = AppState(connections: [favorite, history])

    #expect(state.favoriteConnections == [favorite])
    #expect(state.historyConnections == [history])
}

@MainActor
@Test func exportConnectionsReturnsPortableData() throws {
    let state = AppState(connections: [.samplePassword])

    let data = try state.exportConnections()
    let json = String(decoding: data, as: UTF8.self)

    #expect(json.contains("\"connections\""))
    #expect(json.contains("\"localhost\""))
    #expect(!json.contains("secret"))
}

@MainActor
@Test func importConnectionsMergesNewRecordsAndSkipsDuplicates() async throws {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let existing = ConnectionRecord.samplePassword
    let imported = ConnectionRecord(
        alias: "Imported",
        host: "imported.example.com",
        username: "deploy",
        authentication: .password
    )
    let data = try ImportExportService().export([existing, imported])
    let state = AppState(
        connections: [existing],
        connectionStore: ConnectionStore(fileURL: storeURL)
    )

    try await state.importConnections(from: data)

    #expect(state.connections.map(\.host) == ["localhost", "imported.example.com"])

    let reloaded = try await ConnectionStore(fileURL: storeURL).load()
    #expect(reloaded.connections.map(\.host) == ["localhost", "imported.example.com"])
}

@MainActor
@Test func sendInputAppendsToSelectedTabTranscript() {
    let tab = TerminalTab(title: "Shell", state: .connected, transcript: "$ ")
    let state = AppState(tabs: [tab], connections: [])
    state.selectedTabID = tab.id

    state.sendInputToSelectedTab("ls\n")

    #expect(state.tabs.first?.transcript == "$ ls\n")
}

@MainActor
@Test func failedTransferRemainsVisibleWithErrorMessage() {
    let tab = TerminalTab(title: "Shell", state: .connected, transcript: "")
    let state = AppState(tabs: [tab], connections: [], transfers: [
        TransferRecord(
            sessionID: tab.id,
            direction: .download,
            localPath: "/tmp/app.log",
            remotePath: "/var/log/app.log",
            state: .failed,
            errorMessage: "Permission denied"
        )
    ])
    state.selectedTabID = tab.id

    #expect(state.visibleTransfers.first?.errorMessage == "Permission denied")
}

@MainActor
@Test func cancelTransferMarksRunningTransferCancelled() {
    let tab = TerminalTab(title: "Shell", state: .connected, transcript: "")
    let transfer = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: "/tmp/app.log",
        remotePath: "/var/log/app.log",
        state: .running
    )
    let state = AppState(tabs: [tab], connections: [], transfers: [transfer])

    state.cancelTransfer(transfer.id)

    #expect(state.transfers.first?.state == .cancelled)
}

@MainActor
@Test func retryFailedDownloadClearsErrorAndCompletesTransfer() async throws {
    let session = FakeSSHSession(record: .samplePassword)
    let tab = TerminalTab(title: "Shell", state: .connected, transcript: "", session: session)
    let transfer = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: "/tmp/retry.log",
        remotePath: "/var/log/retry.log",
        state: .failed,
        errorMessage: "Network lost"
    )
    let state = AppState(
        tabs: [tab],
        connections: [],
        transfers: [transfer],
        sftpService: RetrySFTPService(totalBytes: 4)
    )
    state.selectedTabID = tab.id

    await state.retryTransfer(transfer.id)

    #expect(state.transfers.first?.state == .completed)
    #expect(state.transfers.first?.errorMessage == nil)
    #expect(state.transfers.first?.bytesCompleted == 4)
}

@MainActor
@Test func uploadAndDownloadCreateCompletedTransfers() async {
    let state = AppState(
        tabs: [TerminalTab(
            title: "Connected",
            state: .connected,
            transcript: "",
            session: FakeSSHSession(record: .samplePassword)
        )],
        connections: [],
        sftpService: FakeSFTPService()
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/var/www"

    await state.uploadFile(localPath: "/tmp/local.txt")
    await state.downloadFile(remoteFile: RemoteFile(
        name: "local.txt",
        path: "/var/www/local.txt",
        kind: .file,
        size: 1
    ), localPath: "/tmp/local.txt")

    #expect(state.transfers.count == 2)
    #expect(state.transfers.allSatisfy { $0.state == TransferRecord.State.completed })
    #expect(state.remoteFiles.contains { $0.path == "/var/www/local.txt" })
}

@MainActor
@Test func visibleTransfersOnlyIncludesSelectedTabIncompleteTransfers() {
    let first = TerminalTab(title: "First", state: .connected, transcript: "")
    let second = TerminalTab(title: "Second", state: .connected, transcript: "")
    let state = AppState(
        tabs: [first, second],
        connections: [],
        transfers: [
            TransferRecord(
                sessionID: first.id,
                direction: .download,
                localPath: "/tmp/first.bin",
                remotePath: "/first.bin",
                state: .running
            ),
            TransferRecord(
                sessionID: second.id,
                direction: .download,
                localPath: "/tmp/second.bin",
                remotePath: "/second.bin",
                state: .running
            ),
            TransferRecord(
                sessionID: first.id,
                direction: .upload,
                localPath: "/tmp/done.bin",
                remotePath: "/done.bin",
                state: .completed
            )
        ]
    )
    state.selectedTabID = first.id

    #expect(state.visibleTransfers.map(\.remotePath) == ["/first.bin"])
}

@MainActor
@Test func downloadFileResumesFromExistingLocalBytesAndTracksProgress() async throws {
    let localURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("bin")
    try Data(repeating: 0, count: 3).write(to: localURL)
    let state = AppState(
        tabs: [TerminalTab(
            title: "Connected",
            state: .connected,
            transcript: "",
            session: FakeSSHSession(record: .samplePassword)
        )],
        connections: [],
        sftpService: ProgressRecordingSFTPService(totalBytes: 10)
    )
    state.selectedTabID = state.tabs[0].id

    await state.downloadFile(
        remoteFile: RemoteFile(name: "archive.tgz", path: "/tmp/archive.tgz", kind: .file, size: 10),
        localPath: localURL.path
    )

    #expect(state.transfers.count == 1)
    #expect(state.transfers[0].bytesCompleted == 10)
    #expect(state.transfers[0].totalBytes == 10)
    #expect(state.transfers[0].state == .completed)
}

@MainActor
@Test func uploadFileToRemoteDirectoryUsesThatDirectory() async {
    let session = FakeSSHSession(record: .samplePassword)
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id

    await state.uploadFile(
        localPath: "/tmp/site.conf",
        toRemoteDirectory: RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
    )

    #expect(state.transfers.first?.remotePath == "/var/www/logs/site.conf")
    let files = try? await service.list(path: "/var/www/logs", session: session)
    #expect(files == [
        RemoteFile(name: "site.conf", path: "/var/www/logs/site.conf", kind: .file, size: 1)
    ])
}

@MainActor
@Test func createRemoteDirectoryRefreshesCurrentFileList() async {
    let session = FakeSSHSession(record: .samplePassword)
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/var/www"

    await state.createRemoteDirectory(named: " releases ")

    #expect(state.remoteFiles.contains {
        $0 == RemoteFile(name: "releases", path: "/var/www/releases", kind: .directory, size: 0)
    })
}

@MainActor
@Test func createRemoteDirectoryKeepsRefreshPinnedToOriginalTab() async {
    let firstSession = FakeSSHSession(record: .samplePassword)
    let secondSession = FakeSSHSession(record: ConnectionRecord(
        alias: "Second",
        host: "second.example.com",
        username: "deploy",
        authentication: .password
    ))
    let first = TerminalTab(
        title: "First",
        state: .connected,
        transcript: "",
        remotePath: "/var/www",
        session: firstSession
    )
    let second = TerminalTab(
        title: "Second",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: secondSession
    )
    let service = SlowMutationSFTPService(
        firstPathFiles: [RemoteFile(name: "releases", path: "/var/www/releases", kind: .directory, size: 0)],
        secondPathFiles: [RemoteFile(name: "other.txt", path: "/srv/other.txt", kind: .file, size: 1)]
    )
    let state = AppState(tabs: [first, second], connections: [], sftpService: service)
    state.selectedTabID = first.id
    state.remotePath = first.remotePath

    async let createTask: Void = state.createRemoteDirectory(named: "releases")
    await service.waitUntilMutationStarted()
    await state.selectTab(second.id)
    await service.finishMutation()
    await createTask

    #expect(state.selectedTabID == second.id)
    #expect(state.remotePath == "/srv")
    #expect(state.remoteFiles == [
        RemoteFile(name: "other.txt", path: "/srv/other.txt", kind: .file, size: 1)
    ])

    await state.selectTab(first.id)

    #expect(state.remotePath == "/var/www")
    #expect(state.remoteFiles == [
        RemoteFile(name: "releases", path: "/var/www/releases", kind: .directory, size: 0)
    ])
}

@MainActor
@Test func renameRemoteFileRefreshesCurrentFileList() async {
    let session = FakeSSHSession(record: .samplePassword)
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/var/www"
    try? await service.upload(localPath: "/tmp/old.txt", remotePath: "/var/www/old.txt", session: session)

    await state.renameRemoteFile(
        RemoteFile(name: "old.txt", path: "/var/www/old.txt", kind: .file, size: 1),
        to: "new.txt"
    )

    #expect(state.remoteFiles.contains { $0.name == "new.txt" })
    #expect(!state.remoteFiles.contains { $0.name == "old.txt" })
}

@MainActor
@Test func deleteRemoteFileRefreshesCurrentFileList() async {
    let session = FakeSSHSession(record: .samplePassword)
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/var/www"
    try? await service.upload(localPath: "/tmp/delete.txt", remotePath: "/var/www/delete.txt", session: session)

    await state.deleteRemoteFile(RemoteFile(name: "delete.txt", path: "/var/www/delete.txt", kind: .file, size: 1))

    #expect(!state.remoteFiles.contains { $0.name == "delete.txt" })
}

private struct HangingSSHClient: SSHClientProviding {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        try await Task.sleep(for: .seconds(60))
        return FakeSSHSession(record: record)
    }
}

private struct FailingSSHClient: SSHClientProviding {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        throw SSHConnectionTimeoutError(message: "连接失败")
    }
}

private actor UnsupportedSFTPSession: SSHSessionProviding {
    let id = UUID()
    let record = ConnectionRecord.samplePassword
    var state: SSHSessionState { .connected }
    func send(_ input: String) async throws {}
    func drainOutput() async -> String { "" }
    func disconnect() async throws {}
}

private actor RecordingSFTPService: SFTPServicing {
    private let filesByPath: [String: [RemoteFile]]
    private(set) var listedPaths: [String] = []

    init(filesByPath: [String: [RemoteFile]]) {
        self.filesByPath = filesByPath
    }

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        listedPaths.append(path)
        return filesByPath[path] ?? []
    }

    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {}

    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {}

    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {}

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}
}

private actor SlowMutationSFTPService: SFTPServicing {
    private let firstPathFiles: [RemoteFile]
    private let secondPathFiles: [RemoteFile]
    private var mutationStarted: CheckedContinuation<Void, Never>?
    private var mutationCanFinish: CheckedContinuation<Void, Never>?
    private var hasStartedMutation = false

    init(firstPathFiles: [RemoteFile], secondPathFiles: [RemoteFile]) {
        self.firstPathFiles = firstPathFiles
        self.secondPathFiles = secondPathFiles
    }

    func waitUntilMutationStarted() async {
        if hasStartedMutation {
            return
        }

        await withCheckedContinuation { continuation in
            mutationStarted = continuation
        }
    }

    func finishMutation() {
        mutationCanFinish?.resume()
        mutationCanFinish = nil
    }

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        if path == "/var/www" {
            return firstPathFiles
        }
        if path == "/srv" {
            return secondPathFiles
        }
        return []
    }

    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {}

    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {}

    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {}

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {
        hasStartedMutation = true
        mutationStarted?.resume()
        mutationStarted = nil
        await withCheckedContinuation { continuation in
            mutationCanFinish = continuation
        }
    }

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}
}

private actor ProgressRecordingSFTPService: SFTPServicing {
    private let totalBytes: Int64

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] { [] }

    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {}

    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {}

    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {
        await progress(offset, totalBytes)
        await progress(totalBytes, totalBytes)
    }

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}
}

private actor RetrySFTPService: SFTPServicing {
    private let totalBytes: Int64

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] { [] }

    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {}

    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {}

    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {
        await progress(totalBytes, totalBytes)
    }

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}
}

@Test func welcomeTabUsesChineseTermTPBrandName() {
    #expect(TerminalTab.welcome.transcript.contains("欢迎使用 TermTP"))
}

@Test func layoutUsesCompactRightSidebarAndBottomTransferArea() {
    #expect(AppLayout.minimumWindowWidth == 720)
    #expect(AppLayout.minimumWindowHeight == 560)
    #expect(AppLayout.defaultWindowWidth == 760)
    #expect(AppLayout.defaultWindowHeight == 620)
    #expect(AppLayout.connectionSidebarWidth == 190)
    #expect(AppLayout.transferDrawerHeight == 260)
}
