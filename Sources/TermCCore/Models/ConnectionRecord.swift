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
    public var id: UUID
    public var alias: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authentication: ConnectionAuthentication
    public var tags: [String]
    public var isFavorite: Bool
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
        isFavorite: Bool = false,
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
        self.isFavorite = isFavorite
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
