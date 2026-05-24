import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case zhHans = "zh-Hans"
    case en
    case ja
    case ko
    case es
    case fr
    case de
    case ru
    case pt

    static let `default`: AppLanguage = .zhHans

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .ru: return "Русский"
        case .pt: return "Português"
        }
    }
}

struct AppStrings: Equatable, Sendable {
    let currentLanguage: AppLanguage

    init(language: AppLanguage) {
        self.currentLanguage = language
    }

    private var dictionary: [String: String] {
        var values = Self.values[.en] ?? [:]
        values.merge(Self.resolvedValues(for: currentLanguage)) { _, new in new }
        return values
    }

    subscript(_ key: String) -> String {
        dictionary[key] ?? Self.values[.en]?[key] ?? key
    }

    var settings: String { self["settings"] }
    var language: String { self["language"] }
    var terminalTheme: String { self["terminalTheme"] }
    var security: String { self["security"] }
    var trustedHostKeys: String { self["trustedHostKeys"] }
    var noTrustedHostKeys: String { self["noTrustedHostKeys"] }
    var clearTrustedHostKeys: String { self["clearTrustedHostKeys"] }
    func terminalThemeName(_ theme: TerminalTheme) -> String {
        self["terminalTheme.\(theme.rawValue)"]
    }
    var newConnection: String { self["newConnection"] }
    var cancel: String { self["cancel"] }
    var ok: String { self["ok"] }
    var connect: String { self["connect"] }
    var connections: String { self["connections"] }
    var search: String { self["search"] }
    var recent: String { self["recent"] }
    var favorites: String { self["favorites"] }
    var history: String { self["history"] }
    var clearHistory: String { self["clearHistory"] }
    var importConnections: String { self["importConnections"] }
    var exportConnections: String { self["exportConnections"] }
    func importConnectionsFailed(_ message: String) -> String {
        String(format: self["importConnectionsFailedFormat"], message)
    }
    func exportConnectionsFailed(_ message: String) -> String {
        String(format: self["exportConnectionsFailedFormat"], message)
    }
    var noConnections: String { self["noConnections"] }
    var addToFavorites: String { self["addToFavorites"] }
    var removeFromFavorites: String { self["removeFromFavorites"] }
    var delete: String { self["delete"] }
    var alias: String { self["alias"] }
    var group: String { self["group"] }
    var host: String { self["host"] }
    var port: String { self["port"] }
    var username: String { self["username"] }
    var tags: String { self["tags"] }
    var usePrivateKey: String { self["usePrivateKey"] }
    var privateKeyPath: String { self["privateKeyPath"] }
    var privateKeyPassphrase: String { self["privateKeyPassphrase"] }
    var password: String { self["password"] }
    var connection: String { self["connection"] }
    var keepConnectionAlive: String { self["keepConnectionAlive"] }
    var aliveIntervalSeconds: String { self["aliveIntervalSeconds"] }
    var aliveMaxCount: String { self["aliveMaxCount"] }
    var jumpHost: String { self["jumpHost"] }
    var defaultRemotePath: String { self["defaultRemotePath"] }
    var portForwarding: String { self["portForwarding"] }
    var enableForwarding: String { self["enableForwarding"] }
    var type: String { self["type"] }
    var local: String { self["local"] }
    var remote: String { self["remote"] }
    var dynamic: String { self["dynamic"] }
    var bindAddress: String { self["bindAddress"] }
    var destinationHost: String { self["destinationHost"] }
    var destinationPort: String { self["destinationPort"] }
    var trustHostKeyTitle: String { self["trustHostKeyTitle"] }
    var reject: String { self["reject"] }
    var trust: String { self["trust"] }
    var toggleConnections: String { self["toggleConnections"] }
    var toggleSFTPDrawer: String { self["toggleSFTPDrawer"] }
    var commandSnippets: String { self["commandSnippets"] }
    var listFiles: String { self["listFiles"] }
    var diskUsage: String { self["diskUsage"] }
    var memoryUsage: String { self["memoryUsage"] }
    var processMonitor: String { self["processMonitor"] }
    var serverStatus: String { self["serverStatus"] }
    var smallerFont: String { self["smallerFont"] }
    var largerFont: String { self["largerFont"] }
    var fontSize: String { self["fontSize"] }
    var refresh: String { self["refresh"] }
    var connectSFTP: String { self["connectSFTP"] }
    var parentDirectory: String { self["parentDirectory"] }
    var remotePath: String { self["remotePath"] }
    var uploadHere: String { self["uploadHere"] }
    var newFolder: String { self["newFolder"] }
    var rename: String { self["rename"] }
    var name: String { self["name"] }
    var open: String { self["open"] }
    var download: String { self["download"] }
    var preview: String { self["preview"] }
    var changePermissions: String { self["changePermissions"] }
    var permissions: String { self["permissions"] }
    var invalidPermissions: String { self["invalidPermissions"] }
    func previewFailed(_ message: String) -> String {
        String(format: self["previewFailedFormat"], message)
    }
    func permissionsChangeFailed(_ message: String) -> String {
        String(format: self["permissionsChangeFailedFormat"], message)
    }
    var choosePrivateKey: String { self["choosePrivateKey"] }
    var done: String { self["done"] }
    var failed: String { self["failed"] }
    var cancelled: String { self["cancelled"] }
    var queued: String { self["queued"] }
    var running: String { self["running"] }
    var retry: String { self["retry"] }
    var transfers: String { self["transfers"] }
    var clearFinishedTransfers: String { self["clearFinishedTransfers"] }
    func secondsRemaining(_ seconds: Int) -> String {
        String(format: self["secondsRemainingFormat"], seconds)
    }
    func minutesSecondsRemaining(_ minutes: Int, _ seconds: Int) -> String {
        String(format: self["minutesSecondsRemainingFormat"], minutes, seconds)
    }
    var renameTab: String { self["renameTab"] }
    var title: String { self["title"] }
    var close: String { self["close"] }
    var copy: String { self["copy"] }
    var paste: String { self["paste"] }
    var confirmMultilinePasteTitle: String { self["confirmMultilinePasteTitle"] }
    var confirmMultilinePasteMessage: String { self["confirmMultilinePasteMessage"] }
    var showTermTP: String { self["showTermTP"] }
    var quitTermTP: String { self["quitTermTP"] }
    var view: String { self["view"] }
    var welcomeTitle: String { self["welcomeTitle"] }
    var welcomeMessage: String { self["welcomeMessage"] }
    var connectingTo: String { self["connectingTo"] }
    var connectedTo: String { self["connectedTo"] }
    var failedToConnect: String { self["failedToConnect"] }
    var noActiveSSHSession: String { self["noActiveSSHSession"] }
    var sftpUnsupportedForConnection: String { self["sftpUnsupportedForConnection"] }
    var sftpPasswordTitle: String { self["sftpPasswordTitle"] }
    var sftpPasswordMessage: String { self["sftpPasswordMessage"] }
    func sftpRefreshFailed(_ message: String) -> String {
        String(format: self["sftpRefreshFailedFormat"], message)
    }
    func connectionTimedOut(seconds: Double) -> String {
        String(format: self["connectionTimedOutFormat"], "\(seconds)")
    }

    static var requiredKeys: Set<String> {
        Set(values[.en]?.keys ?? [:].keys)
    }

    static var commonInterfaceKeys: Set<String> {
        [
            "terminalTheme", "recent", "clearHistory", "importConnections", "exportConnections",
            "noConnections", "addToFavorites", "removeFromFavorites", "alias", "username",
            "usePrivateKey", "privateKeyPath", "password", "keepConnectionAlive", "jumpHost",
            "portForwarding", "trustHostKeyTitle", "toggleConnections", "commandSnippets",
            "listFiles", "diskUsage", "memoryUsage", "serverStatus", "fontSize", "refresh",
            "connectSFTP",
            "parentDirectory", "remotePath", "newFolder", "renameTab", "copy", "paste",
            "showTermTP", "quitTermTP", "welcomeTitle", "connectingTo", "connectedTo",
            "failedToConnect", "noActiveSSHSession"
        ]
    }

    static func keys(for language: AppLanguage) -> Set<String> {
        Set(resolvedValues(for: language).keys)
    }

    static func rawValue(for key: String, language: AppLanguage) -> String {
        resolvedValues(for: language)[key] ?? ""
    }

    private static func resolvedValues(for language: AppLanguage) -> [String: String] {
        var values = Self.values[language] ?? [:]
        values.merge(Self.supplementalLocalizedValues[language] ?? [:]) { _, new in new }
        return values
    }
}
