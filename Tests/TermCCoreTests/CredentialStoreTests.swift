import XCTest
@testable import TermCCore

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
}
