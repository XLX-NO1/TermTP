import XCTest
@testable import TermCCore

final class SSHConfigurationTests: XCTestCase {
    func testPasswordConfigurationSummary() {
        let summary = SSHConfigurationSummary(record: .samplePassword, credential: .password("pw"))
        XCTAssertEqual(summary.host, "localhost")
        XCTAssertEqual(summary.port, 22)
        XCTAssertEqual(summary.username, "me")
        XCTAssertEqual(summary.authenticationKind, .password)
    }

    func testPublicKeyConfigurationSummary() {
        let record = ConnectionRecord(alias: "Key", host: "host", username: "deploy", authentication: .publicKey(privateKeyPath: "/tmp/key"))
        let summary = SSHConfigurationSummary(record: record, credential: .privateKeyPassphrase("pw"))
        XCTAssertEqual(summary.authenticationKind, .publicKey)
        XCTAssertEqual(summary.privateKeyPath, "/tmp/key")
    }

    func testPublicKeyAuthenticationRejectsPasswordCredential() {
        let record = ConnectionRecord(alias: "Key", host: "host", username: "deploy", authentication: .publicKey(privateKeyPath: "/tmp/key"))

        XCTAssertThrowsError(try CitadelSSHClient().authenticationMethod(for: record, credential: .password("pw"))) { error in
            XCTAssertEqual(error as? SSHClientAdapterError, .missingCredential)
        }
    }
}
