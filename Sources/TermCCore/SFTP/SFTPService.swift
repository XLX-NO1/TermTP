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
        "/var/www": RemoteFile(name: "www", path: "/var/www", kind: .directory, size: 0),
        "/var/www/logs": RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
    ]

    public init() {}

    public func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        guard files[path]?.kind == .directory else { throw SFTPServiceError.notFound(path) }

        return files.values
            .filter { parentPath(for: $0.path) == path }
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
        guard files[remotePath] != nil else { throw SFTPServiceError.notFound(remotePath) }
        files[remotePath] = nil
    }

    private func parentPath(for path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return parent == "/" ? "" : parent
    }
}

public enum SFTPServiceError: Error, Equatable {
    case notFound(String)
}
