import Citadel
import Foundation
import NIOCore

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

    private func parentPath(for path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return parent == "/" ? "" : parent
    }
}

public struct CitadelSFTPService: SFTPServicing {
    public init() {}

    public func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        let citadelSession = try citadelSession(from: session)
        return try await citadelSession.client.withSFTP { sftp in
            let entries = try await sftp.listDirectory(atPath: path)
            return entries.flatMap { name in
                name.components.compactMap { component in
                    guard component.filename != "." && component.filename != ".." else {
                        return nil
                    }

                    let fullPath = path == "/" ? "/\(component.filename)" : "\(path)/\(component.filename)"
                    return RemoteFile(
                        name: component.filename,
                        path: fullPath,
                        kind: component.attributes.permissions.map { $0 & 0o040000 != 0 ? .directory : .file } ?? .file,
                        size: Int64(component.attributes.size ?? 0)
                    )
                }
            }
        }
    }

    public func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {
        let citadelSession = try citadelSession(from: session)
        let input = try FileHandle(forReadingFrom: URL(fileURLWithPath: localPath))
        defer {
            try? input.close()
        }

        try await citadelSession.client.withSFTP { sftp in
            try await sftp.withFile(
                filePath: remotePath,
                flags: [.write, .create, .truncate]
            ) { file in
                var offset: UInt64 = 0
                while true {
                    let data = try input.read(upToCount: 256 * 1024) ?? Data()
                    guard !data.isEmpty else {
                        break
                    }

                    try await file.write(ByteBuffer(data: data), at: offset)
                    offset += UInt64(data.count)
                }
            }
        }
    }

    public func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {
        try await download(remotePath: remotePath, localPath: localPath, resumeFrom: 0, progress: { _, _ in }, session: session)
    }

    public func download(
        remotePath: String,
        localPath: String,
        resumeFrom offset: Int64,
        progress: @escaping ProgressHandler,
        session: SSHSessionProviding
    ) async throws {
        let citadelSession = try citadelSession(from: session)
        try await citadelSession.client.withSFTP { sftp in
            try await sftp.withFile(filePath: remotePath, flags: .read) { file in
                let totalBytes = Int64(try await file.readAttributes().size ?? 0)
                var currentOffset = offset > totalBytes ? 0 : max(0, min(offset, totalBytes))
                let outputURL = URL(fileURLWithPath: localPath)
                FileManager.default.createFile(atPath: outputURL.path, contents: nil)
                let output = try FileHandle(forWritingTo: outputURL)
                defer {
                    try? output.close()
                }
                if offset > totalBytes {
                    try output.truncate(atOffset: 0)
                } else {
                    try output.seekToEnd()
                }
                await progress(currentOffset, totalBytes)

                while currentOffset < totalBytes {
                    var buffer = try await file.read(
                        from: UInt64(currentOffset),
                        length: UInt32(min(256 * 1024, totalBytes - currentOffset))
                    )
                    guard buffer.readableBytes > 0 else {
                        break
                    }

                    let data = buffer.readData(length: buffer.readableBytes) ?? Data()
                    try output.write(contentsOf: data)
                    currentOffset += Int64(data.count)
                    await progress(currentOffset, totalBytes)
                }
            }
        }
    }

    public func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {
        let citadelSession = try citadelSession(from: session)
        try await citadelSession.client.withSFTP { sftp in
            try await sftp.createDirectory(atPath: remotePath)
        }
    }

    public func delete(remotePath: String, kind: RemoteFile.Kind = .file, session: SSHSessionProviding) async throws {
        let citadelSession = try citadelSession(from: session)
        try await citadelSession.client.withSFTP { sftp in
            switch kind {
            case .file:
                try await sftp.remove(at: remotePath)
            case .directory:
                try await sftp.rmdir(at: remotePath)
            }
        }
    }

    public func rename(remotePath: String, to newRemotePath: String, session: SSHSessionProviding) async throws {
        let citadelSession = try citadelSession(from: session)
        try await citadelSession.client.withSFTP { sftp in
            try await sftp.rename(at: remotePath, to: newRemotePath)
        }
    }

    private func citadelSession(from session: SSHSessionProviding) throws -> CitadelSSHSession {
        guard let citadelSession = session as? CitadelSSHSession else {
            throw SFTPServiceError.unsupportedSession
        }
        return citadelSession
    }
}

public enum SFTPServiceError: Error, Equatable {
    case notFound(String)
    case unsupportedSession
}
