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
            group: "Production",
            isFavorite: true,
            defaultRemotePath: "/var/www",
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

    func testDecodingLegacyConnectionRecordUsesDefaultsForNewFields() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "alias": "Legacy",
          "host": "legacy.example.com",
          "port": 22,
          "username": "deploy",
          "authentication": {
            "password": {}
          },
          "tags": ["prod"],
          "isFavorite": true,
          "lastConnectedAt": "2026-05-13T10:00:00Z",
          "createdAt": "2026-05-13T09:00:00Z",
          "updatedAt": "2026-05-13T09:30:00Z"
        }
        """

        let record = try JSONDecoder.termc.decode(
            ConnectionRecord.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(record.keepAlive, .init())
        XCTAssertNil(record.jumpHost)
        XCTAssertTrue(record.portForwards.isEmpty)
        XCTAssertNil(record.defaultRemotePath)
        XCTAssertNil(record.group)
    }
}
