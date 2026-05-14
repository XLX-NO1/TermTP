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

    func testDefaultHostKeyPolicyRequiresExplicitVerificationStrategy() {
        XCTAssertThrowsError(try CitadelSSHClient().makeHostKeyValidator()) { error in
            XCTAssertEqual(error as? SSHClientAdapterError, .hostKeyVerificationRequired)
        }
    }

    func testInsecureHostKeyPolicyIsExplicitOptIn() throws {
        _ = try CitadelSSHClient(hostKeyPolicy: .insecureAcceptAnyHostKey).makeHostKeyValidator()
    }

    func testHostKeyTrustStoreRecordsPromptAndSavesTrustedKey() async throws {
        let store = InMemoryHostKeyTrustStore(trustNewHosts: true)
        let prompt = HostKeyPrompt(
            host: "example.com",
            port: 22,
            key: "ssh-ed25519 AAAA",
            fingerprint: "SHA256:test"
        )

        let trusted = await store.requestTrust(for: prompt)
        let prompts = await store.prompts
        let trustedKey = await store.trustedKey(host: "example.com", port: 22)

        XCTAssertTrue(trusted)
        XCTAssertEqual(prompts, [prompt])
        XCTAssertEqual(trustedKey, "ssh-ed25519 AAAA")
    }
}
