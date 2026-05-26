import Foundation

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
    public var createdAt: Date
    public var updatedAt: Date
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        direction: Direction,
        localPath: String,
        remotePath: String,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0,
        state: State = .queued,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        finishedAt: Date? = nil
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finishedAt = finishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionID
        case direction
        case localPath
        case remotePath
        case bytesCompleted
        case totalBytes
        case state
        case errorMessage
        case createdAt
        case updatedAt
        case finishedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        self.id = try container.decode(UUID.self, forKey: .id)
        self.sessionID = try container.decode(UUID.self, forKey: .sessionID)
        self.direction = try container.decode(Direction.self, forKey: .direction)
        self.localPath = try container.decode(String.self, forKey: .localPath)
        self.remotePath = try container.decode(String.self, forKey: .remotePath)
        self.bytesCompleted = try container.decodeIfPresent(Int64.self, forKey: .bytesCompleted) ?? 0
        self.totalBytes = try container.decodeIfPresent(Int64.self, forKey: .totalBytes) ?? 0
        self.state = try container.decode(State.self, forKey: .state)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        self.finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
    }

    public var bytesPerSecond: Double {
        let elapsed = max(0, updatedAt.timeIntervalSince(createdAt))
        guard elapsed > 0, bytesCompleted > 0 else {
            return 0
        }

        return Double(bytesCompleted) / elapsed
    }

    public var estimatedSecondsRemaining: TimeInterval? {
        guard state == .running, totalBytes > 0, bytesCompleted < totalBytes else {
            return nil
        }

        let speed = bytesPerSecond
        guard speed > 0 else {
            return nil
        }

        return Double(totalBytes - bytesCompleted) / speed
    }
}
