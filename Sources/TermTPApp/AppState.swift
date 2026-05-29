import Foundation
import Observation
import TermTPCore

@Observable
@MainActor
final class AppState {
    static var defaultConnectionStoreURL: URL {
        defaultApplicationSupportDirectory
            .appendingPathComponent("connections.json")
    }

    static var defaultCredentialStoreURL: URL {
        defaultApplicationSupportDirectory
            .appendingPathComponent("credentials.json")
    }

    private static var defaultApplicationSupportDirectory: URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("TermTPTests-\(UUID().uuidString)", isDirectory: true)
        }

        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
    }

    let sshClient: any SSHClientProviding
    let credentialStore: any CredentialStoring
    let legacyCredentialStore: FileCredentialStore
    let sftpService: any SFTPServicing
    let connectionStore: ConnectionStore
    let connectionTimeoutSeconds: Double
    let hostKeyTrustStore: AppHostKeyTrustStore

    var isSidebarVisible = true
    var isSFTPDrawerVisible = true
    var terminalFontSize = 9
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
    var transferTasks: [TransferRecord.ID: Task<Void, Never>] = [:]
    var connections: [ConnectionRecord]
    var transfers: [TransferRecord]
    var notification: AppNotification?
    var isConnectionFormPresented = false
    var isSettingsPresented = false
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
    var pendingSFTPCredentialPrompt: SFTPCredentialPrompt?
    var trustedHostKeyRevision = 0

    var t: AppStrings {
        AppStrings(language: language)
    }

    var terminalPalette: TerminalPalette {
        TerminalPalette.palette(for: terminalTheme)
    }

    var terminalFontSizeOptions: [Int] {
        TerminalFont.sizeOptions
    }

    static let languageDefaultsKey = "TermTP.language"
    static let terminalThemeDefaultsKey = "TermTP.terminalTheme"
    let defaults: UserDefaults

    init(
        tabs: [TerminalTab] = [.welcome],
        connections: [ConnectionRecord] = [.samplePassword],
        transfers: [TransferRecord] = [],
        language: AppLanguage? = nil,
        terminalTheme: TerminalTheme? = nil,
        defaults: UserDefaults = .standard,
        sshClient: (any SSHClientProviding)? = nil,
        credentialStore: any CredentialStoring = KeychainCredentialStore(),
        legacyCredentialStore: FileCredentialStore = FileCredentialStore(fileURL: AppState.defaultCredentialStoreURL),
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
        self.legacyCredentialStore = legacyCredentialStore
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
}
