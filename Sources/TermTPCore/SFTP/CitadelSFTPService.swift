import Citadel
import Foundation
import NIOCore

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
                        size: Int64(component.attributes.size ?? 0),
                        permissions: component.attributes.permissions
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
                    try Task.checkCancellation()
                    let data = try input.read(upToCount: 256 * 1024) ?? Data()
                    guard !data.isEmpty else {
                        break
                    }

                    try await file.write(ByteBuffer(data: data), at: offset)
                    offset += UInt64(data.count)
                    try Task.checkCancellation()
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
                    try Task.checkCancellation()
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
                    try Task.checkCancellation()
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

    public func previewText(remotePath: String, byteLimit: Int, session: SSHSessionProviding) async throws -> String {
        let citadelSession = try citadelSession(from: session)
        return try await citadelSession.client.withSFTP { sftp in
            try await sftp.withFile(filePath: remotePath, flags: .read) { file in
                var buffer = try await file.read(from: 0, length: UInt32(max(1, byteLimit)))
                let data = buffer.readData(length: buffer.readableBytes) ?? Data()
                if let text = String(data: data, encoding: .utf8) {
                    return text
                }

                return String(decoding: data, as: UTF8.self)
            }
        }
    }

    public func changePermissions(remotePath: String, permissions: UInt32, session: SSHSessionProviding) async throws {
        let citadelSession = try citadelSession(from: session)
        try await citadelSession.client.withSFTP { sftp in
            var attributes = SFTPFileAttributes()
            attributes.permissions = permissions
            try await sftp.setAttributes(at: remotePath, to: attributes)
        }
    }

    private func citadelSession(from session: SSHSessionProviding) throws -> CitadelSSHSession {
        guard let citadelSession = session as? CitadelSSHSession else {
            throw SFTPServiceError.unsupportedSession
        }
        return citadelSession
    }
}
