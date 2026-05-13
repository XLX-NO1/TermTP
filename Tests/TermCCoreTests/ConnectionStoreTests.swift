import XCTest
@testable import TermCCore

final class ConnectionStoreTests: XCTestCase {
    func testSaveLoadFavoriteAndClearHistory() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let store = ConnectionStore(fileURL: url)

        var record = ConnectionRecord.samplePassword
        record.isFavorite = true
        try await store.upsert(record)
        try await store.addHistory(HistoryRecord(connection: record, connectedAt: Date(timeIntervalSince1970: 300)))

        let snapshot = try await store.load()
        XCTAssertEqual(snapshot.connections, [record])
        XCTAssertEqual(snapshot.favorites, [record])
        XCTAssertEqual(snapshot.history.count, 1)

        try await store.clearHistory()
        let cleared = try await store.load()
        XCTAssertEqual(cleared.connections, [record])
        XCTAssertTrue(cleared.history.isEmpty)
    }
}
