import Foundation

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
