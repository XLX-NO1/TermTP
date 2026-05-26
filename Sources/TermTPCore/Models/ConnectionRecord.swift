import Foundation

public enum AuthenticationKind: String, Codable, Equatable, Sendable {
    case password
    case publicKey
}

public enum ConnectionAuthentication: Codable, Equatable, Sendable {
    case password
    case publicKey(privateKeyPath: String)

    public var kind: AuthenticationKind {
        switch self {
        case .password: return .password
        case .publicKey: return .publicKey
        }
    }
}

public struct ConnectionRecord: Codable, Equatable, Identifiable, Sendable {
    public struct KeepAlive: Codable, Equatable, Sendable {
        public var isEnabled: Bool
        public var intervalSeconds: Int
        public var maxCount: Int

        public init(
            isEnabled: Bool = false,
            intervalSeconds: Int = 30,
            maxCount: Int = 3
        ) {
            self.isEnabled = isEnabled
            self.intervalSeconds = intervalSeconds
            self.maxCount = maxCount
        }
    }

    public struct PortForward: Codable, Equatable, Identifiable, Sendable {
        public enum Direction: String, Codable, Equatable, Sendable {
            case local
            case remote
            case dynamic
        }

        public var id: UUID
        public var direction: Direction
        public var bindAddress: String
        public var localPort: UInt16
        public var destinationHost: String
        public var destinationPort: UInt16

        public init(
            id: UUID = UUID(),
            direction: Direction,
            bindAddress: String = "127.0.0.1",
            localPort: UInt16,
            destinationHost: String = "",
            destinationPort: UInt16 = 0
        ) {
            self.id = id
            self.direction = direction
            self.bindAddress = bindAddress
            self.localPort = localPort
            self.destinationHost = destinationHost
            self.destinationPort = destinationPort
        }
    }

    public var id: UUID
    public var alias: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authentication: ConnectionAuthentication
    public var tags: [String]
    public var group: String?
    public var isFavorite: Bool
    public var isHistoryVisible: Bool
    public var keepAlive: KeepAlive
    public var jumpHost: String?
    public var portForwards: [PortForward]
    public var defaultRemotePath: String?
    public var lastConnectedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        alias: String,
        host: String,
        port: UInt16 = 22,
        username: String,
        authentication: ConnectionAuthentication,
        tags: [String] = [],
        group: String? = nil,
        isFavorite: Bool = false,
        isHistoryVisible: Bool = true,
        keepAlive: KeepAlive = KeepAlive(),
        jumpHost: String? = nil,
        portForwards: [PortForward] = [],
        defaultRemotePath: String? = nil,
        lastConnectedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.alias = alias
        self.host = host
        self.port = port
        self.username = username
        self.authentication = authentication
        self.tags = tags
        self.group = group
        self.isFavorite = isFavorite
        self.isHistoryVisible = isHistoryVisible
        self.keepAlive = keepAlive
        self.jumpHost = jumpHost
        self.portForwards = portForwards
        self.defaultRemotePath = defaultRemotePath
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case alias
        case host
        case port
        case username
        case authentication
        case tags
        case group
        case isFavorite
        case isHistoryVisible
        case keepAlive
        case jumpHost
        case portForwards
        case defaultRemotePath
        case lastConnectedAt
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.alias = try container.decode(String.self, forKey: .alias)
        self.host = try container.decode(String.self, forKey: .host)
        self.port = try container.decode(UInt16.self, forKey: .port)
        self.username = try container.decode(String.self, forKey: .username)
        self.authentication = try container.decode(ConnectionAuthentication.self, forKey: .authentication)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.group = try container.decodeIfPresent(String.self, forKey: .group)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.isHistoryVisible = try container.decodeIfPresent(Bool.self, forKey: .isHistoryVisible) ?? true
        self.keepAlive = try container.decodeIfPresent(KeepAlive.self, forKey: .keepAlive) ?? KeepAlive()
        self.jumpHost = try container.decodeIfPresent(String.self, forKey: .jumpHost)
        self.portForwards = try container.decodeIfPresent([PortForward].self, forKey: .portForwards) ?? []
        self.defaultRemotePath = try container.decodeIfPresent(String.self, forKey: .defaultRemotePath)
        self.lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
