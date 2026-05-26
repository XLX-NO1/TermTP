import Foundation

public struct RemoteFile: Equatable, Identifiable, Sendable {
    public enum Kind: Sendable {
        case file
        case directory
    }

    public var id: String { path }
    public var name: String
    public var path: String
    public var kind: Kind
    public var size: Int64
    public var permissions: UInt32?

    public init(name: String, path: String, kind: Kind, size: Int64, permissions: UInt32? = nil) {
        self.name = name
        self.path = path
        self.kind = kind
        self.size = size
        self.permissions = permissions
    }
}
