import Foundation

public protocol SFTPServicing: Sendable {
    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile]
    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws
    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws
    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws
    func delete(remotePath: String, session: SSHSessionProviding) async throws
}

public actor FakeSFTPService: SFTPServicing {
    private var files: [String: RemoteFile] = [
        "/var/www/logs": RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
    ]

    public init() {}

    public func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        files.values
            .filter { $0.path.hasPrefix(path + "/") }
            .sorted { $0.name < $1.name }
    }

    public func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = RemoteFile(name: URL(fileURLWithPath: remotePath).lastPathComponent, path: remotePath, kind: .file, size: 1)
    }

    public func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {
        guard files[remotePath] != nil else { throw SFTPServiceError.notFound(remotePath) }
    }

    public func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = RemoteFile(name: URL(fileURLWithPath: remotePath).lastPathComponent, path: remotePath, kind: .directory, size: 0)
    }

    public func delete(remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = nil
    }
}

public enum SFTPServiceError: Error, Equatable {
    case notFound(String)
}
