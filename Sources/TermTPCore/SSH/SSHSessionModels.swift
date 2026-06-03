import Foundation

public enum SSHSessionState: Equatable, Sendable {
    case connecting
    case localProcessRunning
    case connected
    case disconnected
    case failed(String)
}

public protocol SSHClientProviding: Sendable {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding
}

public protocol SSHSessionProviding: AnyObject, Sendable {
    var id: UUID { get }
    var record: ConnectionRecord { get }
    var state: SSHSessionState { get async }
    func send(_ input: String) async throws
    func drainOutput() async -> String
    func disconnect() async throws
}

public actor FakeSSHSession: SSHSessionProviding {
    public let id = UUID()
    public let record: ConnectionRecord
    private var currentState: SSHSessionState = .connected
    private var output = "Welcome to TermTP\n"

    public init(record: ConnectionRecord) {
        self.record = record
    }

    public var state: SSHSessionState {
        currentState
    }

    public func send(_ input: String) async throws {
        output += input
    }

    public func drainOutput() async -> String {
        let value = output
        output.removeAll()
        return value
    }

    public func disconnect() async throws {
        currentState = .disconnected
    }
}

public struct FakeSSHClient: SSHClientProviding {
    public init() {}

    public func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        FakeSSHSession(record: record)
    }
}
