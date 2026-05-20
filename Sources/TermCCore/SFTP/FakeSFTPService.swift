import Foundation

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

    public func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {
        guard let file = files[remotePath] else { throw SFTPServiceError.notFound(remotePath) }
        let currentOffset = offset > file.size ? 0 : min(offset, file.size)
        if offset > file.size {
            FileManager.default.createFile(atPath: localPath, contents: nil)
            let output = try FileHandle(forWritingTo: URL(fileURLWithPath: localPath))
            try output.truncate(atOffset: 0)
            try output.write(contentsOf: Data(repeating: 0, count: Int(file.size)))
            try output.close()
        } else if currentOffset < file.size {
            FileManager.default.createFile(atPath: localPath, contents: nil)
            let output = try FileHandle(forWritingTo: URL(fileURLWithPath: localPath))
            try output.seekToEnd()
            try output.write(contentsOf: Data(repeating: 0, count: Int(file.size - currentOffset)))
            try output.close()
        }
        await progress(currentOffset, file.size)
        await progress(file.size, file.size)
    }

    public func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = RemoteFile(name: URL(fileURLWithPath: remotePath).lastPathComponent, path: remotePath, kind: .directory, size: 0)
    }

    public func delete(remotePath: String, kind: RemoteFile.Kind = .file, session: SSHSessionProviding) async throws {
        guard files[remotePath] != nil else { throw SFTPServiceError.notFound(remotePath) }
        files[remotePath] = nil
    }

    public func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {
        guard var file = files[remotePath] else { throw SFTPServiceError.notFound(remotePath) }
        files[remotePath] = nil
        file.path = newRemotePath
        file.name = URL(fileURLWithPath: newRemotePath).lastPathComponent
        files[newRemotePath] = file
    }

    public func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String {
        guard let file = files[remotePath], file.kind == .file else { throw SFTPServiceError.notFound(remotePath) }
        return String("Preview: \(file.name)").prefix(byteLimit).description
    }

    public func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {
        guard var file = files[remotePath] else { throw SFTPServiceError.notFound(remotePath) }
        file.permissions = permissions
        files[remotePath] = file
    }

    private func parentPath(for path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return parent == "/" ? "" : parent
    }
}
