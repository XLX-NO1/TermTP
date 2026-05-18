import XCTest
@testable import TermCCore

final class SFTPServiceTests: XCTestCase {
    func testFakeListUploadDownloadDelete() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        let initial = try await service.list(path: "/var/www", session: session)
        XCTAssertEqual(initial.map(\.name), ["logs"])

        try await service.upload(localPath: "/tmp/app.tar.gz", remotePath: "/var/www/app.tar.gz", session: session)
        let afterUpload = try await service.list(path: "/var/www", session: session)
        XCTAssertTrue(afterUpload.contains { $0.name == "app.tar.gz" })

        try await service.download(remotePath: "/var/www/app.tar.gz", localPath: "/tmp/app.tar.gz", session: session)
        try await service.delete(remotePath: "/var/www/app.tar.gz", session: session)
        let afterDelete = try await service.list(path: "/var/www", session: session)
        XCTAssertFalse(afterDelete.contains { $0.name == "app.tar.gz" })
    }

    func testDownloadTruncatesLocalFileWhenResumeOffsetExceedsRemoteSize() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bin")
        try Data(repeating: 0, count: 8).write(to: localURL)
        try await service.upload(localPath: "/tmp/remote.bin", remotePath: "/var/www/remote.bin", session: session)

        try await service.download(
            remotePath: "/var/www/remote.bin",
            localPath: localURL.path,
            resumeFrom: 8,
            progress: { _, _ in },
            session: session
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        XCTAssertEqual(attributes[.size] as? Int64, 1)
    }

    func testListOnlyReturnsDirectChildren() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        try await service.upload(localPath: "/tmp/app.log", remotePath: "/var/www/logs/app.log", session: session)

        let files = try await service.list(path: "/var/www", session: session)
        XCTAssertEqual(files.map(\.name), ["logs"])
    }

    func testListMissingDirectoryThrowsNotFound() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        do {
            _ = try await service.list(path: "/var/www/missing", session: session)
            XCTFail("Expected missing directory to throw notFound")
        } catch let error as SFTPServiceError {
            XCTAssertEqual(error, .notFound("/var/www/missing"))
        }
    }

    func testDeleteMissingFileThrowsNotFound() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        do {
            try await service.delete(remotePath: "/var/www/missing.txt", session: session)
            XCTFail("Expected missing file to throw notFound")
        } catch let error as SFTPServiceError {
            XCTAssertEqual(error, .notFound("/var/www/missing.txt"))
        }
    }

    func testDeleteDirectoryRemovesFakeDirectory() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        try await service.makeDirectory(remotePath: "/var/www/releases", session: session)
        try await service.delete(remotePath: "/var/www/releases", kind: .directory, session: session)

        let files = try await service.list(path: "/var/www", session: session)
        XCTAssertFalse(files.contains { $0.name == "releases" })
    }

    func testRenameMovesFakeFileToNewPath() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        try await service.upload(localPath: "/tmp/old.txt", remotePath: "/var/www/old.txt", session: session)
        try await service.rename(remotePath: "/var/www/old.txt", to: "/var/www/new.txt", session: session)

        let files = try await service.list(path: "/var/www", session: session)
        XCTAssertFalse(files.contains { $0.name == "old.txt" })
        XCTAssertTrue(files.contains { $0.name == "new.txt" && $0.path == "/var/www/new.txt" })
    }

    func testRenameMissingFileThrowsNotFound() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        do {
            try await service.rename(remotePath: "/var/www/missing.txt", to: "/var/www/new.txt", session: session)
            XCTFail("Expected missing file to throw notFound")
        } catch let error as SFTPServiceError {
            XCTAssertEqual(error, .notFound("/var/www/missing.txt"))
        }
    }

    func testPreviewTextReturnsUploadedFileNameForFakeService() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        try await service.upload(localPath: "/tmp/app.log", remotePath: "/var/www/app.log", session: session)

        let preview = try await service.previewText(remotePath: "/var/www/app.log", byteLimit: 64, session: session)

        XCTAssertTrue(preview.contains("app.log"))
    }

    func testChangePermissionsStoresModeOnFakeService() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        try await service.upload(localPath: "/tmp/app.sh", remotePath: "/var/www/app.sh", session: session)
        try await service.changePermissions(remotePath: "/var/www/app.sh", permissions: 0o755, session: session)
        let files = try await service.list(path: "/var/www", session: session)
        let file = try XCTUnwrap(files.first { $0.name == "app.sh" })

        XCTAssertEqual(file.permissions, 0o755)
    }
}
