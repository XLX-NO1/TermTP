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
        values.merge(Self.values[currentLanguage] ?? [:]) { _, new in new }
        return values
    }

    subscript(_ key: String) -> String {
        dictionary[key] ?? Self.values[.en]?[key] ?? key
    }

    var settings: String { self["settings"] }
    var language: String { self["language"] }
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
    var noConnections: String { self["noConnections"] }
    var addToFavorites: String { self["addToFavorites"] }
    var removeFromFavorites: String { self["removeFromFavorites"] }
    var delete: String { self["delete"] }
    var alias: String { self["alias"] }
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
    var refresh: String { self["refresh"] }
    var parentDirectory: String { self["parentDirectory"] }
    var remotePath: String { self["remotePath"] }
    var uploadHere: String { self["uploadHere"] }
    var newFolder: String { self["newFolder"] }
    var rename: String { self["rename"] }
    var name: String { self["name"] }
    var open: String { self["open"] }
    var download: String { self["download"] }
    var done: String { self["done"] }
    var failed: String { self["failed"] }
    var cancelled: String { self["cancelled"] }
    var queued: String { self["queued"] }
    var running: String { self["running"] }
    var renameTab: String { self["renameTab"] }
    var title: String { self["title"] }
    var close: String { self["close"] }
    var copy: String { self["copy"] }
    var paste: String { self["paste"] }
    var showTermTP: String { self["showTermTP"] }
    var quitTermTP: String { self["quitTermTP"] }
    var view: String { self["view"] }
    var welcomeTitle: String { self["welcomeTitle"] }
    var welcomeMessage: String { self["welcomeMessage"] }
    var connectingTo: String { self["connectingTo"] }
    var connectedTo: String { self["connectedTo"] }
    var failedToConnect: String { self["failedToConnect"] }
    var noActiveSSHSession: String { self["noActiveSSHSession"] }
    func connectionTimedOut(seconds: Double) -> String {
        String(format: self["connectionTimedOutFormat"], "\(seconds)")
    }

    private static let values: [AppLanguage: [String: String]] = [
        .zhHans: [
            "settings": "设置",
            "language": "语言",
            "newConnection": "新建连接",
            "cancel": "取消",
            "ok": "确定",
            "connect": "连接",
            "connections": "连接",
            "search": "搜索",
            "recent": "最近",
            "favorites": "收藏",
            "history": "历史",
            "clearHistory": "清空历史",
            "noConnections": "暂无连接",
            "addToFavorites": "加入收藏",
            "removeFromFavorites": "取消收藏",
            "delete": "删除",
            "alias": "别名",
            "host": "主机",
            "port": "端口",
            "username": "用户名",
            "tags": "标签",
            "usePrivateKey": "使用私钥",
            "privateKeyPath": "私钥路径",
            "privateKeyPassphrase": "私钥密码",
            "password": "密码",
            "connection": "连接",
            "keepConnectionAlive": "保持连接",
            "aliveIntervalSeconds": "保活间隔秒数",
            "aliveMaxCount": "保活最大次数",
            "jumpHost": "跳板机",
            "portForwarding": "端口转发",
            "enableForwarding": "启用转发",
            "type": "类型",
            "local": "本地",
            "remote": "远程",
            "dynamic": "动态",
            "bindAddress": "绑定地址",
            "destinationHost": "目标主机",
            "destinationPort": "目标端口",
            "trustHostKeyTitle": "信任 SSH 主机密钥？",
            "reject": "拒绝",
            "trust": "信任",
            "toggleConnections": "显示/隐藏连接栏",
            "toggleSFTPDrawer": "显示/隐藏 SFTP 面板",
            "commandSnippets": "命令片段",
            "listFiles": "列出文件",
            "diskUsage": "磁盘使用",
            "memoryUsage": "内存使用",
            "processMonitor": "进程监控",
            "serverStatus": "服务器状态",
            "smallerFont": "减小字体",
            "largerFont": "增大字体",
            "refresh": "刷新",
            "parentDirectory": "上级目录",
            "remotePath": "远程路径",
            "uploadHere": "上传到这里",
            "newFolder": "新建文件夹",
            "rename": "重命名",
            "name": "名称",
            "open": "打开",
            "download": "下载",
            "done": "完成",
            "failed": "失败",
            "cancelled": "已取消",
            "queued": "排队中",
            "running": "传输中",
            "renameTab": "重命名标签页",
            "title": "标题",
            "close": "关闭",
            "copy": "复制",
            "paste": "粘贴",
            "showTermTP": "显示 TermTP",
            "quitTermTP": "退出 TermTP",
            "view": "视图",
            "welcomeTitle": "欢迎",
            "welcomeMessage": "欢迎使用 TermTP\n\n从连接栏选择主机开始 SSH 会话。",
            "connectingTo": "正在连接",
            "connectedTo": "已连接到",
            "failedToConnect": "连接失败",
            "noActiveSSHSession": "没有可用的 SSH 会话",
            "connectionTimedOutFormat": "连接超时，已等待 %@ 秒"
        ],
        .en: [
            "settings": "Settings",
            "language": "Language",
            "newConnection": "New Connection",
            "cancel": "Cancel",
            "ok": "OK",
            "connect": "Connect",
            "connections": "Connections",
            "search": "Search",
            "recent": "Recent",
            "favorites": "Favorites",
            "history": "History",
            "clearHistory": "Clear History",
            "noConnections": "No connections",
            "addToFavorites": "Add to Favorites",
            "removeFromFavorites": "Remove from Favorites",
            "delete": "Delete",
            "alias": "Alias",
            "host": "Host",
            "port": "Port",
            "username": "Username",
            "tags": "Tags",
            "usePrivateKey": "Use private key",
            "privateKeyPath": "Private key path",
            "privateKeyPassphrase": "Private key passphrase",
            "password": "Password",
            "connection": "Connection",
            "keepConnectionAlive": "Keep connection alive",
            "aliveIntervalSeconds": "Alive interval seconds",
            "aliveMaxCount": "Alive max count",
            "jumpHost": "Jump host",
            "portForwarding": "Port Forwarding",
            "enableForwarding": "Enable forwarding",
            "type": "Type",
            "local": "Local",
            "remote": "Remote",
            "dynamic": "Dynamic",
            "bindAddress": "Bind address",
            "destinationHost": "Destination host",
            "destinationPort": "Destination port",
            "trustHostKeyTitle": "Trust SSH Host Key?",
            "reject": "Reject",
            "trust": "Trust",
            "toggleConnections": "Toggle Connections",
            "toggleSFTPDrawer": "Toggle SFTP Drawer",
            "commandSnippets": "Command Snippets",
            "listFiles": "List files",
            "diskUsage": "Disk usage",
            "memoryUsage": "Memory usage",
            "processMonitor": "Process monitor",
            "serverStatus": "Server status",
            "smallerFont": "Smaller Font",
            "largerFont": "Larger Font",
            "refresh": "Refresh",
            "parentDirectory": "Parent Directory",
            "remotePath": "Remote path",
            "uploadHere": "Upload Here",
            "newFolder": "New Folder",
            "rename": "Rename",
            "name": "Name",
            "open": "Open",
            "download": "Download",
            "done": "Done",
            "failed": "Failed",
            "cancelled": "Cancelled",
            "queued": "Queued",
            "running": "Running",
            "renameTab": "Rename Tab",
            "title": "Title",
            "close": "Close",
            "copy": "Copy",
            "paste": "Paste",
            "showTermTP": "Show TermTP",
            "quitTermTP": "Quit TermTP",
            "view": "View",
            "welcomeTitle": "Welcome",
            "welcomeMessage": "Welcome to TermTP\n\nSelect a connection from the sidebar to start an SSH session.",
            "connectingTo": "Connecting to",
            "connectedTo": "Connected to",
            "failedToConnect": "Failed to connect to",
            "noActiveSSHSession": "No active SSH session",
            "connectionTimedOutFormat": "Connection timed out after %@ seconds"
        ],
        .ja: [
            "settings": "設定",
            "language": "言語",
            "newConnection": "新規接続",
            "cancel": "キャンセル",
            "ok": "OK",
            "connect": "接続",
            "connections": "接続",
            "search": "検索",
            "favorites": "お気に入り",
            "history": "履歴",
            "delete": "削除",
            "download": "ダウンロード",
            "uploadHere": "ここにアップロード"
        ],
        .ko: [
            "settings": "설정",
            "language": "언어",
            "newConnection": "새 연결",
            "cancel": "취소",
            "ok": "확인",
            "connect": "연결",
            "connections": "연결",
            "search": "검색",
            "favorites": "즐겨찾기",
            "history": "기록",
            "delete": "삭제",
            "download": "다운로드",
            "uploadHere": "여기에 업로드"
        ],
        .es: [
            "settings": "Configuración",
            "language": "Idioma",
            "newConnection": "Nueva conexión",
            "cancel": "Cancelar",
            "ok": "Aceptar",
            "connect": "Conectar",
            "connections": "Conexiones",
            "search": "Buscar",
            "favorites": "Favoritos",
            "history": "Historial",
            "delete": "Eliminar",
            "download": "Descargar",
            "uploadHere": "Subir aquí"
        ],
        .fr: [
            "settings": "Réglages",
            "language": "Langue",
            "newConnection": "Nouvelle connexion",
            "cancel": "Annuler",
            "ok": "OK",
            "connect": "Connexion",
            "connections": "Connexions",
            "search": "Rechercher",
            "favorites": "Favoris",
            "history": "Historique",
            "delete": "Supprimer",
            "download": "Télécharger",
            "uploadHere": "Téléverser ici"
        ],
        .de: [
            "settings": "Einstellungen",
            "language": "Sprache",
            "newConnection": "Neue Verbindung",
            "cancel": "Abbrechen",
            "ok": "OK",
            "connect": "Verbinden",
            "connections": "Verbindungen",
            "search": "Suchen",
            "favorites": "Favoriten",
            "history": "Verlauf",
            "delete": "Löschen",
            "download": "Herunterladen",
            "uploadHere": "Hier hochladen"
        ],
        .ru: [
            "settings": "Настройки",
            "language": "Язык",
            "newConnection": "Новое подключение",
            "cancel": "Отмена",
            "ok": "OK",
            "connect": "Подключить",
            "connections": "Подключения",
            "search": "Поиск",
            "favorites": "Избранное",
            "history": "История",
            "delete": "Удалить",
            "download": "Скачать",
            "uploadHere": "Загрузить сюда"
        ],
        .pt: [
            "settings": "Definições",
            "language": "Idioma",
            "newConnection": "Nova conexão",
            "cancel": "Cancelar",
            "ok": "OK",
            "connect": "Conectar",
            "connections": "Conexões",
            "search": "Pesquisar",
            "favorites": "Favoritos",
            "history": "Histórico",
            "delete": "Excluir",
            "download": "Baixar",
            "uploadHere": "Enviar aqui"
        ]
    ]
}
