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
}
