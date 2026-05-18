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
        self.keepAlive = try container.decodeIfPresent(KeepAlive.self, forKey: .keepAlive) ?? KeepAlive()
        self.jumpHost = try container.decodeIfPresent(String.self, forKey: .jumpHost)
        self.portForwards = try container.decodeIfPresent([PortForward].self, forKey: .portForwards) ?? []
        self.defaultRemotePath = try container.decodeIfPresent(String.self, forKey: .defaultRemotePath)
        self.lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

public struct HistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var connectionID: UUID
    public var alias: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authenticationKind: AuthenticationKind
    public var connectedAt: Date

    public init(connection: ConnectionRecord, connectedAt: Date = Date()) {
        self.id = UUID()
        self.connectionID = connection.id
        self.alias = connection.alias
        self.host = connection.host
        self.port = connection.port
        self.username = connection.username
        self.authenticationKind = connection.authentication.kind
        self.connectedAt = connectedAt
    }
}

public struct TransferRecord: Codable, Equatable, Identifiable, Sendable {
    public enum Direction: String, Codable, Sendable {
        case upload
        case download
    }

    public enum State: String, Codable, Sendable {
        case queued
        case running
        case completed
        case failed
        case cancelled
    }

    public var id: UUID
    public var sessionID: UUID
    public var direction: Direction
    public var localPath: String
    public var remotePath: String
    public var bytesCompleted: Int64
    public var totalBytes: Int64
    public var state: State
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        direction: Direction,
        localPath: String,
        remotePath: String,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0,
        state: State = .queued,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.direction = direction
        self.localPath = localPath
        self.remotePath = remotePath
        self.bytesCompleted = bytesCompleted
        self.totalBytes = totalBytes
        self.state = state
        self.errorMessage = errorMessage
    }
}

public extension JSONEncoder {
    static var termc: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var termc: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension ConnectionRecord {
    static let samplePassword = ConnectionRecord(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        alias: "Local",
        host: "localhost",
        port: 22,
        username: "me",
        authentication: .password,
        tags: ["dev"],
        isFavorite: false,
        lastConnectedAt: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
}
