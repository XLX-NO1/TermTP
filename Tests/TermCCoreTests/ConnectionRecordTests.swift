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
            isHistoryVisible: false,
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
        XCTAssertFalse(decoded.isHistoryVisible)
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
        XCTAssertTrue(record.isHistoryVisible)
    }

    func testTransferRecordComputesSpeedAndRemainingTime() {
        let transfer = TransferRecord(
            sessionID: UUID(),
            direction: .download,
            localPath: "/tmp/archive.tgz",
            remotePath: "/srv/archive.tgz",
            bytesCompleted: 50,
            totalBytes: 100,
            state: .running,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(transfer.bytesPerSecond, 5)
        XCTAssertEqual(transfer.estimatedSecondsRemaining, 10)
    }

    func testDecodingLegacyTransferRecordUsesCurrentDates() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "sessionID": "22222222-2222-2222-2222-222222222222",
          "direction": "download",
          "localPath": "/tmp/app.log",
          "remotePath": "/var/log/app.log",
          "bytesCompleted": 10,
          "totalBytes": 20,
          "state": "running"
        }
        """

        let transfer = try JSONDecoder.termc.decode(
            TransferRecord.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(transfer.bytesCompleted, 10)
        XCTAssertEqual(transfer.totalBytes, 20)
        XCTAssertNil(transfer.finishedAt)
        XCTAssertLessThan(abs(transfer.createdAt.timeIntervalSinceNow), 2)
    }
}
