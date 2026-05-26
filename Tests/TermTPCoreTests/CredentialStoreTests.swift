import XCTest
@testable import TermTPCore

final class CredentialStoreTests: XCTestCase {
    func testInMemoryCredentialStoreRoundTripsAndDeletes() async throws {
        let store = InMemoryCredentialStore()
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        try await store.save(.password("secret"), for: id)
        let savedCredential = try await store.load(for: id)
        XCTAssertEqual(savedCredential, .password("secret"))

        try await store.delete(for: id)
        let deletedCredential = try await store.load(for: id)
        XCTAssertNil(deletedCredential)
    }

    func testFileCredentialStoreRoundTripsDeletesAndUsesRestrictedPermissions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("credentials.json")
        let store = FileCredentialStore(fileURL: url)
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

        try await store.save(.password("secret"), for: id)
        let savedCredential = try await store.load(for: id)

        XCTAssertEqual(savedCredential, .password("secret"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.uint16Value, 0o600)

        try await store.delete(for: id)
        let deletedCredential = try await store.load(for: id)

        XCTAssertNil(deletedCredential)
    }
}
