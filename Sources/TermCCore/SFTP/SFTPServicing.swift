import Foundation

public protocol SFTPServicing: Sendable {
    typealias ProgressHandler = @Sendable (Int64, Int64) async -> Void

    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile]
    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws
    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws
    func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws
    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws
    func delete(remotePath: String, kind: RemoteFile.Kind, session: SSHSessionProviding) async throws
    func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws
    func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String
    func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws
}
