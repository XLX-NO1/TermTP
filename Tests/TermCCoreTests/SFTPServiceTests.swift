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
}
