import XCTest
@testable import TermCCore

final class ImportExportServiceTests: XCTestCase {
    func testExportOmitsSecretsAndImportsRecords() throws {
        let service = ImportExportService()
        let records = [
            ConnectionRecord.samplePassword,
            ConnectionRecord(
                alias: "Key",
                host: "key.example.com",
                username: "deploy",
                authentication: .publicKey(privateKeyPath: "/Users/me/.ssh/id_ed25519")
            )
        ]

        let data = try service.export(records)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("passphrase"))
        XCTAssertFalse(json.contains("keychain"))

        let imported = try service.import(data)
        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].host, "localhost")
        XCTAssertEqual(imported[1].authentication.kind, .publicKey)
    }
}
