import AppKit
import Testing
import TermTPCore
@testable import TermTPApp

@MainActor
@Test func defaultCredentialStoreUsesKeychain() {
    let state = AppState(connections: [])

    #expect(state.credentialStore is KeychainCredentialStore)
}

@MainActor
@Test func migrateLegacyFileCredentialsCopiesSecretsAndRemovesPlaintextStore() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("credentials.json")
    let legacyStore = FileCredentialStore(fileURL: url)
    let credentialStore = InMemoryCredentialStore()
    let id = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    try await legacyStore.save(.password("secret"), for: id)
    let state = AppState(
        connections: [],
        credentialStore: credentialStore,
        legacyCredentialStore: legacyStore
    )

    await state.migrateLegacyFileCredentialsIfNeeded()

    let migratedCredential = try await credentialStore.load(for: id)
    #expect(migratedCredential == .password("secret"))
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@MainActor
@Test func terminalFontSizeOptionsCoverEveryIntegerSize() {
    let state = AppState(connections: [])

    #expect(state.terminalFontSizeOptions == TerminalFont.sizeOptions)
    #expect(state.terminalFontSizeOptions == (8...12).map { $0 })
}

@MainActor
@Test func terminalFontSizeDefaultsToNineOnLaunch() {
    let state = AppState(connections: [])

    #expect(state.terminalFontSize == 9)
}

@Test func terminalFontMetricsChangeForEveryAdjacentSize() {
    let sizes = Array(8...12)
    let metrics = sizes.map { TerminalFont.cellMetrics(for: $0, scale: 2) }

    for index in metrics.indices.dropLast() {
        #expect(metrics[index] != metrics[index + 1])
    }
}

@Test func terminalFontUsesVisiblePointSizeSteps() {
    let sizes = Array(8...12)
    let pointSizes = sizes.map(TerminalFont.pointSize)

    #expect(pointSizes.first == 8)
    for index in pointSizes.indices.dropLast() {
        #expect(pointSizes[index + 1] - pointSizes[index] >= 2)
    }
}

@Test func terminalFontUsesFixedPitchFontForEverySizeOption() {
    for size in TerminalFont.sizeOptions {
        let font = TerminalFont.make(size: size)

        #expect(font.pointSize == TerminalFont.pointSize(for: size))
        #expect(font.isFixedPitch)
    }
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
@Test func settingsPanelCanBePresentedFromMainWindowChrome() {
    let state = AppState(connections: [])

    #expect(!state.isSettingsPresented)

    state.showSettings()

    #expect(state.isSettingsPresented)

    state.dismissSettings()

    #expect(!state.isSettingsPresented)
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
@Test func refreshRemoteFilesDoesNotPromptForSFTPCredentialWhenTerminalUsedManualPassword() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let state = AppState(
        tabs: [tab],
        connections: [],
        language: .zhHans,
        sshClient: RecordingSSHClient(),
        sftpService: RecordingSFTPService(filesByPath: [
            "/srv": [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)]
        ])
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"

    await state.refreshRemoteFiles()

    #expect(state.pendingSFTPCredentialPrompt == nil)
    #expect(state.notification == nil)
    #expect(state.remoteFiles.isEmpty)
}

@MainActor
@Test func connectSFTPForSelectedTabPromptsWhenManualPasswordConnectionHasNoSavedCredential() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let state = AppState(
        tabs: [tab],
        connections: [],
        credentialStore: InMemoryCredentialStore()
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"

    await state.connectSFTPForSelectedTab()

    #expect(state.pendingSFTPCredentialPrompt?.tabID == tab.id)
    #expect(state.pendingSFTPCredentialPrompt?.connection == connection)
    #expect(state.remoteFiles.isEmpty)
}

@MainActor
@Test func connectSFTPForSelectedTabUsesSavedPasswordForManualConnection() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let credentialStore = InMemoryCredentialStore()
    try? await credentialStore.save(.password("secret"), for: connection.id)
    let sshClient = RecordingSSHClient()
    let sftpService = RecordingSFTPService(filesByPath: [
        "/srv": [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)]
    ])
    let state = AppState(
        tabs: [tab],
        connections: [],
        sshClient: sshClient,
        credentialStore: credentialStore,
        sftpService: sftpService
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"

    await state.connectSFTPForSelectedTab()

    #expect(await sshClient.credentials == [.password("secret")])
    #expect(state.pendingSFTPCredentialPrompt == nil)
    #expect(state.remoteFiles == [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)])
    #expect(await sftpService.listedPaths == ["/srv"])
}

@MainActor
@Test func connectSFTPForSelectedTabPromptsAgainAndDeletesSavedPasswordWhenAuthenticationFails() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let credentialStore = InMemoryCredentialStore()
    try? await credentialStore.save(.password("stale"), for: connection.id)
    let state = AppState(
        tabs: [tab],
        connections: [],
        language: .zhHans,
        sshClient: AuthenticationFailingSSHClient(),
        credentialStore: credentialStore,
        sftpService: RecordingSFTPService(filesByPath: [:])
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"

    await state.connectSFTPForSelectedTab()

    let savedCredential = try? await credentialStore.load(for: connection.id)
    #expect(savedCredential == nil)
    #expect(state.pendingSFTPCredentialPrompt?.tabID == tab.id)
    #expect(state.notification?.message == "认证失败，请重新输入密码")
}

@MainActor
@Test func submitSFTPCredentialCreatesFileManagementSessionForManualPasswordConnection() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let sshClient = RecordingSSHClient()
    let sftpService = RecordingSFTPService(filesByPath: [
        "/srv": [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)]
    ])
    let state = AppState(
        tabs: [tab],
        connections: [],
        sshClient: sshClient,
        sftpService: sftpService
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"
    await state.connectSFTPForSelectedTab()

    await state.submitSFTPCredential(password: "secret")

    #expect(await sshClient.credentials == [.password("secret")])
    #expect(state.pendingSFTPCredentialPrompt == nil)
    #expect(state.remoteFiles == [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)])
    #expect(await sftpService.listedPaths == ["/srv"])
}

@MainActor
@Test func submitSFTPCredentialWaitsForHostKeyTrustBeforeConnectionTimeout() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let sshClient = HostKeyPromptingSSHClient()
    let sftpService = RecordingSFTPService(filesByPath: [
        "/srv": [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)]
    ])
    let state = AppState(
        tabs: [tab],
        connections: [],
        sshClient: sshClient,
        sftpService: sftpService,
        connectionTimeoutSeconds: 0.01
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"
    await state.connectSFTPForSelectedTab()

    let submitTask = Task {
        await state.submitSFTPCredential(password: "secret")
    }
    await sshClient.waitUntilPrompting()
    state.pendingHostKeyPrompt = HostKeyPrompt(
        host: connection.host,
        port: connection.port,
        key: "ssh-ed25519 AAAATEST",
        fingerprint: "SHA256:test"
    )
    try? await Task.sleep(for: .milliseconds(35))
    state.pendingHostKeyPrompt = nil
    await sshClient.finish()
    await submitTask.value

    #expect(state.pendingSFTPCredentialPrompt == nil)
    #expect(state.notification == nil)
    #expect(state.remoteFiles == [RemoteFile(name: "app.log", path: "/srv/app.log", kind: .file, size: 5)])
}

@MainActor
@Test func submitSFTPCredentialCanAvoidSavingManualPassword() async {
    let connection = ConnectionRecord(
        alias: "Manual",
        host: "manual.example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let tab = TerminalTab(
        title: "Manual",
        state: .connected,
        transcript: "",
        remotePath: "/srv",
        session: LocalSSHOnlySession(record: connection)
    )
    let credentialStore = InMemoryCredentialStore()
    let state = AppState(
        tabs: [tab],
        connections: [],
        sshClient: RecordingSSHClient(),
        credentialStore: credentialStore,
        sftpService: RecordingSFTPService(filesByPath: ["/srv": []])
    )
    state.selectedTabID = tab.id
    state.remotePath = "/srv"
    await state.connectSFTPForSelectedTab()

    await state.submitSFTPCredential(password: "secret", saveCredential: false)

    let savedCredential = try? await credentialStore.load(for: connection.id)
    #expect(savedCredential == nil)
    #expect(state.pendingSFTPCredentialPrompt == nil)
}

@MainActor
@Test func menuBarTemplateImageFallsBackWhenResourceIsMissing() {
    let image = MenuBarController.makeMenuBarTemplateImage()

    #expect(image.size == .init(width: 18, height: 18))
    #expect(image.isTemplate)
}

@MainActor
@Test func menuBarFallbackImageUsesTerminalPromptMark() {
    let image = MenuBarController.makeFallbackMenuBarTemplateImage()

    #expect(image.size == .init(width: 18, height: 18))
    #expect(image.isTemplate)
    #expect(menuBarImageHasInk(image, in: NSRect(x: 3, y: 5, width: 7, height: 8)))
    #expect(menuBarImageHasInk(image, in: NSRect(x: 9, y: 5, width: 6, height: 2)))
    #expect(!menuBarImageHasInk(image, in: NSRect(x: 7, y: 14, width: 4, height: 3)))
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
@Test func connectDraftConnectionWithEmptyPasswordStartsInteractiveLocalSSH() async {
    let credentialStore = InMemoryCredentialStore()
    let state = AppState(
        connections: [],
        sshClient: FailingSSHClient(),
        credentialStore: credentialStore,
        sftpService: RecordingSFTPService(filesByPath: [:])
    )
    state.draftAlias = "Manual Password"
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = " \n "
    state.draftPrivateKeyPassphrase = "stale-key-passphrase"
    state.draftDefaultRemotePath = " /srv "

    await state.connectDraftConnection()

    let connection = state.connections[0]

    #expect(state.tabs.last?.state == .connected)
    #expect(state.tabs.last?.localProcess == .ssh(connection, credential: nil))
    let savedCredential = try? await credentialStore.load(for: connection.id)
    #expect(savedCredential == nil)
    #expect(state.remotePath == "/srv")
    #expect(state.tabs.last?.remotePath == "/srv")
    #expect(state.remoteFiles.isEmpty)
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
@Test func savedPasswordAuthenticationFailureKeepsTerminalOnSystemSSHAndPromptsForSFTPPassword() async {
    let connection = ConnectionRecord(
        alias: "Saved Password",
        host: "example.com",
        username: "deploy",
        authentication: .password,
        defaultRemotePath: "/srv"
    )
    let credentialStore = InMemoryCredentialStore()
    try? await credentialStore.save(.password("stale"), for: connection.id)
    let state = AppState(
        connections: [connection],
        language: .zhHans,
        sshClient: AuthenticationFailingSSHClient(),
        credentialStore: credentialStore,
        sftpService: RecordingSFTPService(filesByPath: [:])
    )

    await state.connect(connection)

    #expect(state.tabs.last?.state == .connected)
    if case .ssh(let fallbackConnection, let credential) = state.tabs.last?.localProcess {
        #expect(fallbackConnection.id == connection.id)
        #expect(credential == .password("stale"))
    } else {
        Issue.record("Expected local SSH terminal")
    }
    let savedCredential = try? await credentialStore.load(for: connection.id)
    #expect(savedCredential == nil)
    #expect(state.pendingSFTPCredentialPrompt?.connection.id == connection.id)
    #expect(state.notification == nil)
}

@MainActor
@Test func savedPasswordTransportFailureFallsBackToLocalSSHWithPassword() async {
    let connection = ConnectionRecord(
        alias: "LAN",
        host: "192.168.3.55",
        username: "root",
        authentication: .password,
        defaultRemotePath: "/root"
    )
    let credentialStore = InMemoryCredentialStore()
    try? await credentialStore.save(.password("secret"), for: connection.id)
    let state = AppState(
        connections: [connection],
        sshClient: NoRouteSSHClient(),
        credentialStore: credentialStore,
        sftpService: RecordingSFTPService(filesByPath: [:])
    )

    await state.connect(connection)

    #expect(state.tabs.last?.state == .connected)
    if case .ssh(let fallbackConnection, let credential) = state.tabs.last?.localProcess {
        #expect(fallbackConnection.id == connection.id)
        #expect(credential == .password("secret"))
    } else {
        Issue.record("Expected local SSH fallback with saved password")
    }
    #expect(state.remoteFiles.isEmpty)
}

@MainActor
@Test func savedPasswordTransportFailureAutoConnectsSFTPAfterLocalSSHFallback() async {
    let connection = ConnectionRecord(
        alias: "LAN",
        host: "192.168.3.55",
        username: "root",
        authentication: .password,
        defaultRemotePath: "/root"
    )
    let credentialStore = InMemoryCredentialStore()
    try? await credentialStore.save(.password("secret"), for: connection.id)
    let sshClient = RecordingSSHClient()
    let sftpService = RecordingSFTPService(filesByPath: [
        "/root": [RemoteFile(name: "deploy.sh", path: "/root/deploy.sh", kind: .file, size: 8)]
    ])
    let state = AppState(
        connections: [connection],
        sshClient: sshClient,
        credentialStore: credentialStore,
        sftpService: sftpService
    )

    await state.connect(connection)

    #expect(state.tabs.last?.state == .connected)
    #expect(await sshClient.credentials == [.password("secret")])
    #expect(state.pendingSFTPCredentialPrompt == nil)
    #expect(state.remoteFiles == [RemoteFile(name: "deploy.sh", path: "/root/deploy.sh", kind: .file, size: 8)])
    #expect(await sftpService.listedPaths == ["/root"])
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
@Test func hostKeyTrustStoreDoesNotImportSystemKnownHostsEntries() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let trustedKeysURL = directory.appendingPathComponent("trusted-host-keys.json")
    let knownHostsURL = directory.appendingPathComponent("known_hosts")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try """
    # Existing system SSH trust
    192.168.3.55 ssh-ed25519 AAAALAN
    [example.com]:2222 ssh-rsa AAAAPORT
    |1|hashed|host ssh-ed25519 AAAAHASHED

    """.write(to: knownHostsURL, atomically: true, encoding: .utf8)

    let store = AppHostKeyTrustStore(fileURL: trustedKeysURL)

    #expect(store.trustedHostKeys.isEmpty)
    #expect(await store.trustedKey(host: "192.168.3.55", port: 22) == nil)
    #expect(await store.trustedKey(host: "example.com", port: 2222) == nil)
    #expect(!FileManager.default.fileExists(atPath: trustedKeysURL.path))
}

@MainActor
@Test func clearTrustedHostKeysAlsoClearsLocalSSHKnownHostsFile() throws {
    let state = AppState(connections: [])
    let knownHostsURL = TermTPKnownHostsFile.defaultFileURL
    try FileManager.default.createDirectory(
        at: knownHostsURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try "example.com ssh-ed25519 AAAATEST\n".write(to: knownHostsURL, atomically: true, encoding: .utf8)

    state.clearTrustedHostKeys()

    #expect(!FileManager.default.fileExists(atPath: knownHostsURL.path))
}

@MainActor
@Test func removeTrustedHostKeyAlsoRemovesMatchingLocalSSHKnownHostsEntry() async throws {
    let state = AppState(connections: [])
    let knownHostsURL = TermTPKnownHostsFile.defaultFileURL
    try FileManager.default.createDirectory(
        at: knownHostsURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try """
    example.com ssh-ed25519 AAAATEST
    other.example.com ssh-ed25519 AAAAOTHER
    [example.com]:2222 ssh-ed25519 AAAAPORT

    """.write(to: knownHostsURL, atomically: true, encoding: .utf8)
    try await state.hostKeyTrustStore.saveTrustedKey("ssh-ed25519 AAAATEST", host: "example.com", port: 22)
    try await state.hostKeyTrustStore.saveTrustedKey("ssh-ed25519 AAAAOTHER", host: "other.example.com", port: 22)

    state.removeTrustedHostKey(hostPort: "example.com:22")

    let knownHosts = try String(contentsOf: knownHostsURL, encoding: .utf8)
    #expect(!knownHosts.contains("example.com ssh-ed25519 AAAATEST"))
    #expect(knownHosts.contains("other.example.com ssh-ed25519 AAAAOTHER"))
    #expect(knownHosts.contains("[example.com]:2222 ssh-ed25519 AAAAPORT"))
    #expect(await state.hostKeyTrustStore.trustedKey(host: "example.com", port: 22) == nil)
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
    state.draftUsesKey = true
    state.draftPrivateKeyPath = "/tmp/slow-key"

    await state.connectDraftConnection()

    #expect(state.tabs.last?.state == .failed("连接超时，已等待 0.01 秒"))
    #expect(state.tabs.last?.transcript.contains("连接超时，已等待 0.01 秒") == true)
    #expect(state.connections.isEmpty)
}

@MainActor
@Test func connectDraftConnectionWaitsForHostKeyTrustBeforeConnectionTimeout() async {
    let sshClient = HostKeyPromptingSSHClient()
    let state = AppState(
        connections: [],
        sshClient: sshClient,
        sftpService: RecordingSFTPService(filesByPath: [:]),
        connectionTimeoutSeconds: 0.01
    )
    state.draftAlias = "LAN"
    state.draftHost = "192.168.1.20"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = "secret"

    let connectTask = Task {
        await state.connectDraftConnection()
    }
    await sshClient.waitUntilPrompting()
    state.pendingHostKeyPrompt = HostKeyPrompt(
        host: "192.168.1.20",
        port: 22,
        key: "ssh-ed25519 AAAALAN",
        fingerprint: "SHA256:lan"
    )
    try? await Task.sleep(for: .milliseconds(35))
    state.pendingHostKeyPrompt = nil
    await sshClient.finish()
    await connectTask.value

    #expect(state.tabs.last?.state == .connected)
    #expect(state.connections.first?.host == "192.168.1.20")
}

@MainActor
@Test func connectDraftPasswordConnectionPersistsWhenBackgroundSFTPConnectionFails() async {
    let credentialStore = InMemoryCredentialStore()
    let state = AppState(
        connections: [],
        language: .zhHans,
        sshClient: FailingSSHClient(),
        credentialStore: credentialStore
    )
    state.draftAlias = "Broken"
    state.draftHost = "broken.example.com"
    state.draftPort = "22"
    state.draftUsername = "deploy"
    state.draftPassword = "secret"

    await state.connectDraftConnection()

    #expect(state.connections.count == 1)
    #expect(state.tabs.last?.state == .connected)
    #expect(state.tabs.last?.localProcess == .ssh(state.connections[0], credential: .password("secret")))
    let savedCredential = try? await credentialStore.load(for: state.connections[0].id)
    #expect(savedCredential == .password("secret"))
    #expect(state.remoteFiles.isEmpty)
    #expect(state.notification == nil)
}

@MainActor
@Test func hostKeyTrustPromptsResolveInRequestOrder() async {
    let store = AppHostKeyTrustStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json"))
    var visiblePrompts: [HostKeyPrompt?] = []
    let first = HostKeyPrompt(host: "one.example.com", port: 22, key: "ssh-ed25519 AAAAONE", fingerprint: "SHA256:one")
    let second = HostKeyPrompt(host: "two.example.com", port: 22, key: "ssh-ed25519 AAAATWO", fingerprint: "SHA256:two")
    store.onPromptChanged = { visiblePrompts.append($0) }

    let firstTask = Task { await store.requestTrust(for: first) }
    await Task.yield()
    let secondTask = Task { await store.requestTrust(for: second) }
    await Task.yield()

    #expect(store.pendingPrompt == first)
    store.resolvePendingPrompt(trusted: true)
    await Task.yield()
    #expect(await firstTask.value)
    #expect(store.pendingPrompt == second)

    store.resolvePendingPrompt(trusted: false)
    await Task.yield()
    #expect(await secondTask.value == false)
    #expect(store.pendingPrompt == nil)
    #expect(await store.trustedKey(host: "one.example.com", port: 22) == "ssh-ed25519 AAAAONE")
    #expect(await store.trustedKey(host: "two.example.com", port: 22) == nil)
    #expect(visiblePrompts.compactMap { $0 } == [first, second])
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
@Test func closeTabDisconnectsClosedSession() async {
    let first = TerminalTab(title: "First", state: .connected, transcript: "")
    let session = DisconnectRecordingSession(record: ConnectionRecord(
        alias: "Second",
        host: "second.example.com",
        username: "deploy",
        authentication: .password
    ))
    let second = TerminalTab(title: "Second", state: .connected, transcript: "", session: session)
    let state = AppState(tabs: [first, second], connections: [])
    state.selectedTabID = second.id

    await state.closeTab(second.id)

    #expect(await session.didDisconnect)
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
@Test func clearHistoryHidesHistoryWithoutDeletingFavoritesOrRecentItems() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    favorite.lastConnectedAt = Date(timeIntervalSince1970: 100)
    let history = ConnectionRecord(
        alias: "History",
        host: "history.example.com",
        username: "deploy",
        authentication: .password,
        lastConnectedAt: Date(timeIntervalSince1970: 200)
    )
    let state = AppState(connections: [favorite, history])

    state.clearHistory()

    #expect(state.connections.count == 2)
    #expect(state.favoriteConnections.map(\.id) == [favorite.id])
    #expect(state.historyConnections.isEmpty)
    #expect(state.recentConnections.map(\.id) == [history.id, favorite.id])
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
@Test func loadConnectionsPreservesCurrentConnectionsWhenStoredFileIsCorrupt() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try Data("{ broken json".utf8).write(to: url)
    let existing = ConnectionRecord.samplePassword
    let state = AppState(
        connections: [existing],
        language: .zhHans,
        connectionStore: ConnectionStore(fileURL: url)
    )

    await state.loadConnections()

    #expect(state.connections == [existing])
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(state.notification?.kind == .error)
    #expect(state.notification?.message.contains("读取连接记录失败") == true)
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
@Test func deleteFavoriteKeepsHistoryAndRecentMembership() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    favorite.lastConnectedAt = Date(timeIntervalSince1970: 100)
    let state = AppState(connections: [favorite])

    state.deleteFavoriteConnection(favorite.id)

    #expect(state.favoriteConnections.isEmpty)
    #expect(state.historyConnections.map(\.id) == [favorite.id])
    #expect(state.recentConnections.map(\.id) == [favorite.id])
}

@MainActor
@Test func deleteHistoryConnectionKeepsFavoriteAndRecentMembership() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    favorite.lastConnectedAt = Date(timeIntervalSince1970: 100)
    let state = AppState(connections: [favorite])

    state.deleteHistoryConnection(favorite.id)

    #expect(state.connections.count == 1)
    #expect(state.favoriteConnections.map(\.id) == [favorite.id])
    #expect(state.historyConnections.isEmpty)
    #expect(state.recentConnections.map(\.id) == [favorite.id])
}

@MainActor
@Test func deleteRecentConnectionKeepsFavoriteAndHistoryMembership() {
    var favorite = ConnectionRecord.samplePassword
    favorite.isFavorite = true
    favorite.lastConnectedAt = Date(timeIntervalSince1970: 100)
    let state = AppState(connections: [favorite])

    state.deleteRecentConnection(favorite.id)

    #expect(state.connections.count == 1)
    #expect(state.favoriteConnections.map(\.id) == [favorite.id])
    #expect(state.historyConnections.map(\.id) == [favorite.id])
    #expect(state.recentConnections.isEmpty)
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
@Test func historyConnectionsIncludeFavoritesWhenHistoryIsVisible() {
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
    #expect(state.historyConnections == [favorite, history])
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
    let localPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("log")
        .path
    let transfer = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: localPath,
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
@Test func retryFailedDownloadUsesOriginalTransferSessionWhenAnotherTabIsSelected() async throws {
    let firstRecord = ConnectionRecord(
        alias: "First",
        host: "first.example.com",
        username: "deploy",
        authentication: .password
    )
    let secondRecord = ConnectionRecord(
        alias: "Second",
        host: "second.example.com",
        username: "deploy",
        authentication: .password
    )
    let firstSession = FakeSSHSession(record: firstRecord)
    let secondSession = FakeSSHSession(record: secondRecord)
    let first = TerminalTab(title: "First", state: .connected, transcript: "", session: firstSession)
    let second = TerminalTab(title: "Second", state: .connected, transcript: "", session: secondSession)
    let localPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("log")
        .path
    let transfer = TransferRecord(
        sessionID: first.id,
        direction: .download,
        localPath: localPath,
        remotePath: "/var/log/retry.log",
        state: .failed,
        errorMessage: "Network lost"
    )
    let service = SessionRecordingSFTPService()
    let state = AppState(
        tabs: [first, second],
        connections: [],
        transfers: [transfer],
        sftpService: service
    )
    state.selectedTabID = second.id

    await state.retryTransfer(transfer.id)

    #expect(await service.downloadHosts == ["first.example.com"])
    #expect(state.transfers.first?.state == .completed)
}

@MainActor
@Test func retryFailedUploadUsesOriginalTransferSessionWhenAnotherTabIsSelected() async throws {
    let firstRecord = ConnectionRecord(
        alias: "First",
        host: "first.example.com",
        username: "deploy",
        authentication: .password
    )
    let secondRecord = ConnectionRecord(
        alias: "Second",
        host: "second.example.com",
        username: "deploy",
        authentication: .password
    )
    let firstSession = FakeSSHSession(record: firstRecord)
    let secondSession = FakeSSHSession(record: secondRecord)
    let first = TerminalTab(title: "First", state: .connected, transcript: "", session: firstSession)
    let second = TerminalTab(title: "Second", state: .connected, transcript: "", session: secondSession)
    let transfer = TransferRecord(
        sessionID: first.id,
        direction: .upload,
        localPath: "/tmp/retry.log",
        remotePath: "/var/log/retry.log",
        state: .failed,
        errorMessage: "Network lost"
    )
    let service = SessionRecordingSFTPService()
    let state = AppState(
        tabs: [first, second],
        connections: [],
        transfers: [transfer],
        sftpService: service
    )
    state.selectedTabID = second.id

    await state.retryTransfer(transfer.id)

    #expect(await service.uploadHosts == ["first.example.com"])
    #expect(state.transfers.first?.state == .completed)
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
                state: .completed,
                finishedAt: Date(timeIntervalSinceNow: -10)
            )
        ]
    )
    state.selectedTabID = first.id

    #expect(state.visibleTransfers.map(\.remotePath) == ["/first.bin"])
}

@MainActor
@Test func visibleTransfersKeepsRecentlyCompletedTransfersAndHidesOldCompletedTransfers() {
    let tab = TerminalTab(title: "First", state: .connected, transcript: "")
    let recent = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: "/tmp/recent.bin",
        remotePath: "/recent.bin",
        state: .completed,
        finishedAt: Date()
    )
    let old = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: "/tmp/old.bin",
        remotePath: "/old.bin",
        state: .completed,
        finishedAt: Date(timeIntervalSinceNow: -10)
    )
    let failed = TransferRecord(
        sessionID: tab.id,
        direction: .download,
        localPath: "/tmp/failed.bin",
        remotePath: "/failed.bin",
        state: .failed
    )
    let state = AppState(tabs: [tab], connections: [], transfers: [recent, old, failed])
    state.selectedTabID = tab.id

    #expect(state.visibleTransfers.map(\.remotePath) == ["/recent.bin", "/failed.bin"])
}

@MainActor
@Test func clearFinishedTransfersRemovesCompletedAndCancelledTransfersForSelectedTab() {
    let first = TerminalTab(title: "First", state: .connected, transcript: "")
    let second = TerminalTab(title: "Second", state: .connected, transcript: "")
    let state = AppState(
        tabs: [first, second],
        connections: [],
        transfers: [
            TransferRecord(sessionID: first.id, direction: .download, localPath: "/tmp/done.bin", remotePath: "/done.bin", state: .completed),
            TransferRecord(sessionID: first.id, direction: .download, localPath: "/tmp/cancelled.bin", remotePath: "/cancelled.bin", state: .cancelled),
            TransferRecord(sessionID: first.id, direction: .download, localPath: "/tmp/failed.bin", remotePath: "/failed.bin", state: .failed),
            TransferRecord(sessionID: second.id, direction: .download, localPath: "/tmp/other.bin", remotePath: "/other.bin", state: .completed)
        ]
    )
    state.selectedTabID = first.id

    state.clearFinishedTransfersForSelectedTab()

    #expect(state.transfers.map(\.remotePath) == ["/failed.bin", "/other.bin"])
}

@MainActor
@Test func downloadFileResumesFromExistingLocalBytesAndTracksProgress() async throws {
    let finalURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("bin")
    let partialURL = URL(fileURLWithPath: finalURL.path + ".termtp-download")
    try Data(repeating: 0, count: 3).write(to: partialURL)
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
        localPath: finalURL.path
    )

    #expect(state.transfers.count == 1)
    #expect(state.transfers[0].bytesCompleted == 10)
    #expect(state.transfers[0].totalBytes == 10)
    #expect(state.transfers[0].state == .completed)
    #expect(FileManager.default.fileExists(atPath: finalURL.path))
    #expect(!FileManager.default.fileExists(atPath: partialURL.path))
}

@MainActor
@Test func downloadFileOverwritesExistingFinalFileInsteadOfTreatingItAsCompleteResume() async throws {
    let finalURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("bin")
    try Data("old-content".utf8).write(to: finalURL)
    let service = ProgressRecordingSFTPService(totalBytes: 10)
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
    state.selectedTabID = state.tabs[0].id

    await state.downloadFile(
        remoteFile: RemoteFile(name: "archive.tgz", path: "/tmp/archive.tgz", kind: .file, size: 10),
        localPath: finalURL.path
    )

    #expect(await service.resumeOffsets == [0])
    #expect(state.transfers.first?.bytesCompleted == 10)
    #expect(try Data(contentsOf: finalURL).count == 10)
    #expect(try Data(contentsOf: finalURL) != Data("old-content".utf8))
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
@Test func uploadFileToRootDirectoryUsesSingleLeadingSlash() async {
    let session = FakeSSHSession(record: .samplePassword)
    let service = FakeSFTPService()
    let state = AppState(
        tabs: [TerminalTab(title: "Connected", state: .connected, transcript: "", remotePath: "/", session: session)],
        connections: [],
        sftpService: service
    )
    state.selectedTabID = state.tabs[0].id
    state.remotePath = "/"

    await state.uploadFile(localPath: "/tmp/site.conf")

    #expect(state.transfers.first?.remotePath == "/site.conf")
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

private struct AuthenticationFailingSSHClient: SSHClientProviding {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        throw TestAuthenticationFailure()
    }
}

private struct NoRouteSSHClient: SSHClientProviding {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        throw TestNoRouteFailure()
    }
}

private actor HostKeyPromptingSSHClient: SSHClientProviding {
    private var promptStarted: CheckedContinuation<Void, Never>?
    private var connectCanFinish: CheckedContinuation<Void, Never>?
    private var isPrompting = false

    func waitUntilPrompting() async {
        if isPrompting {
            return
        }

        await withCheckedContinuation { continuation in
            promptStarted = continuation
        }
    }

    func finish() {
        connectCanFinish?.resume()
        connectCanFinish = nil
    }

    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        isPrompting = true
        promptStarted?.resume()
        promptStarted = nil
        await withCheckedContinuation { continuation in
            connectCanFinish = continuation
        }
        return FakeSSHSession(record: record)
    }
}

private struct TestAuthenticationFailure: Error, CustomStringConvertible {
    var description: String { "allAuthenticationOptionsFailed" }
}

private struct TestNoRouteFailure: Error, CustomStringConvertible {
    var description: String {
        "Connection errors: SingleConnectionFailure(target: [IPv4]192.168.3.55/192.168.3.55:22, error: connect(descriptor:addr:size:): No route to host) (errno: 65))"
    }
}

private actor RecordingSSHClient: SSHClientProviding {
    private(set) var records: [ConnectionRecord] = []
    private(set) var credentials: [Credential?] = []

    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        records.append(record)
        credentials.append(credential)
        return FakeSSHSession(record: record)
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

private actor DisconnectRecordingSession: SSHSessionProviding {
    let id = UUID()
    let record: ConnectionRecord
    private var currentState: SSHSessionState = .connected
    private(set) var didDisconnect = false

    init(record: ConnectionRecord) {
        self.record = record
    }

    var state: SSHSessionState {
        currentState
    }

    func send(_ input: String) async throws {}

    func drainOutput() async -> String { "" }

    func disconnect() async throws {
        didDisconnect = true
        currentState = .disconnected
    }
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

    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String { "" }

    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {}
}

private actor SessionRecordingSFTPService: SFTPServicing {
    private(set) var uploadHosts: [String] = []
    private(set) var downloadHosts: [String] = []

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] { [] }

    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {
        uploadHosts.append(session.record.host)
    }

    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {
        downloadHosts.append(session.record.host)
    }

    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {
        downloadHosts.append(session.record.host)
        writeFakeDownload(to: localPath, offset: offset, totalBytes: 1)
        await progress(1, 1)
    }

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}

    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String { "" }

    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {}
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

    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String { "" }

    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {}
}

@MainActor
private func menuBarImageHasInk(_ image: NSImage, in rect: NSRect) -> Bool {
    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data)
    else {
        return false
    }

    let scaleX = CGFloat(bitmap.pixelsWide) / image.size.width
    let scaleY = CGFloat(bitmap.pixelsHigh) / image.size.height
    let minX = max(0, Int(rect.minX * scaleX))
    let maxX = min(bitmap.pixelsWide - 1, Int(rect.maxX * scaleX))
    let minY = max(0, bitmap.pixelsHigh - Int(rect.maxY * scaleY))
    let maxY = min(bitmap.pixelsHigh - 1, bitmap.pixelsHigh - Int(rect.minY * scaleY))

    for y in minY...maxY {
        for x in minX...maxX {
            if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
                return true
            }
        }
    }

    return false
}

private actor ProgressRecordingSFTPService: SFTPServicing {
    private let totalBytes: Int64
    private(set) var resumeOffsets: [Int64] = []

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
        resumeOffsets.append(offset)
        writeFakeDownload(to: localPath, offset: offset, totalBytes: totalBytes)
        await progress(offset, totalBytes)
        await progress(totalBytes, totalBytes)
    }

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}

    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String { "" }

    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {}
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
        writeFakeDownload(to: localPath, offset: offset, totalBytes: totalBytes)
        await progress(totalBytes, totalBytes)
    }

    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {}

    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws {}

    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {}

    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String { "" }

    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {}
}

private func writeFakeDownload(to path: String, offset: Int64, totalBytes: Int64) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    FileManager.default.createFile(atPath: path, contents: nil)
    guard let output = try? FileHandle(forWritingTo: url) else {
        return
    }
    defer {
        try? output.close()
    }

    do {
        try output.seekToEnd()
    } catch {
        return
    }
    let remainingBytes = max(0, totalBytes - offset)
    try? output.write(contentsOf: Data(repeating: 0, count: Int(remainingBytes)))
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

@MainActor
@Test func sidebarActionButtonsUseReadableDarkThemeColors() {
    #expect(ConnectionSidebarActionStyle.textOpacity == 0.92)
    #expect(ConnectionSidebarActionStyle.backgroundOpacity == 0.07)
    #expect(ConnectionSidebarActionStyle.borderOpacity == 0.12)
    #expect(ConnectionSidebarActionStyle.cornerRadius == 6)
}

@MainActor
@Test func connectionSidebarKeepsActionsPinnedBelowScrollableSections() {
    #expect(ConnectionSidebarLayout.sectionSpacing == 5)
    #expect(ConnectionSidebarLayout.footerSpacing == 7)
    #expect(ConnectionSidebarLayout.collapsibleHeaderHeight == 18)
    #expect(ConnectionSidebarLayout.primarySectionCount == 2)
    #expect(ConnectionSidebarLayout.startsCollapsed)
}

@MainActor
@Test func terminalTabStripUsesScrollableFixedHeightTabs() {
    #expect(TerminalTabStripLayout.height == 34)
    #expect(TerminalTabStripLayout.tabMinWidth == 74)
    #expect(TerminalTabStripLayout.tabMaxWidth == 132)
    #expect(TerminalTabStripLayout.closeButtonSize == 18)
}
