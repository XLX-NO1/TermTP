import XCTest
@testable import TermCCore

final class ConnectionRecordTests: XCTestCase {
    func testConnectionRecordRoundTripsWithoutSecrets() throws {
        let record = ConnectionRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            alias: "Production",
            host: "prod.example.com",
            port: 22,
            username: "deploy",
            authentication: .publicKey(privateKeyPath: "/Users/me/.ssh/id_ed25519"),
            tags: ["prod", "api"],
            isFavorite: true,
            lastConnectedAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let data = try JSONEncoder.termc.encode(record)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("password"))
        XCTAssertFalse(json.contains("passphrase"))

        let decoded = try JSONDecoder.termc.decode(ConnectionRecord.self, from: data)
        XCTAssertEqual(decoded, record)
    }

    func testHistoryRecordFromConnectionDoesNotIncludeSecretFields() {
        let record = ConnectionRecord.samplePassword
        let history = HistoryRecord(connection: record, connectedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(history.host, "localhost")
        XCTAssertEqual(history.authenticationKind, .password)
        XCTAssertEqual(history.connectedAt, Date(timeIntervalSince1970: 200))
    }
}
