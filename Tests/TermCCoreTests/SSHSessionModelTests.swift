import XCTest
@testable import TermCCore

final class SSHSessionModelTests: XCTestCase {
    func testFakeClientConnectsAndEchoesInput() async throws {
        let client = FakeSSHClient()
        let session = try await client.connect(record: .samplePassword, credential: .password("pw"))

        let connectedState = await session.state
        XCTAssertEqual(connectedState, .connected)

        try await session.send("echo hi\n")
        let output = await session.drainOutput()
        XCTAssertTrue(output.contains("Welcome to TermTP"))
        XCTAssertTrue(output.contains("echo hi"))

        try await session.disconnect()
        let disconnectedState = await session.state
        XCTAssertEqual(disconnectedState, .disconnected)
    }
}
