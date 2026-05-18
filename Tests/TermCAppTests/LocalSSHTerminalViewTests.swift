import Foundation
import Testing
import TermCCore
@testable import TermCApp

@MainActor
@Test func passwordLaunchEnvironmentKeepsTermVariable() {
    let askPassScriptPath = "/tmp/termtp-test-askpass.sh"
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: Credential.password("secret"),
        askPassScriptPath: askPassScriptPath
    )

    #expect(launch.environment?.contains("TERM=xterm-256color") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS_REQUIRE=force") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS=\(askPassScriptPath)") == true)
}

@MainActor
@Test func askPassScriptUsesIsolatedTemporaryDirectory() {
    let firstPath = LocalSSHTerminalView.makeAskPassScriptPath()
    let secondPath = LocalSSHTerminalView.makeAskPassScriptPath()

    #expect(firstPath != secondPath)
    #expect(URL(fileURLWithPath: firstPath).lastPathComponent == "ssh-askpass.sh")
    #expect(FileManager.default.isExecutableFile(atPath: firstPath))

    try? FileManager.default.removeItem(at: URL(fileURLWithPath: firstPath).deletingLastPathComponent())
    try? FileManager.default.removeItem(at: URL(fileURLWithPath: secondPath).deletingLastPathComponent())
}

@MainActor
@Test func launchArgumentsIncludeKeepAliveJumpHostAndForwarding() {
    let connection = ConnectionRecord(
        alias: "Production",
        host: "prod.example.com",
        port: 2222,
        username: "deploy",
        authentication: .password,
        keepAlive: .init(isEnabled: true, intervalSeconds: 30, maxCount: 3),
        jumpHost: "jump.example.com",
        portForwards: [
            .init(
                direction: .local,
                bindAddress: "127.0.0.1",
                localPort: 8080,
                destinationHost: "localhost",
                destinationPort: 80
            )
        ]
    )

    let launch = LocalSSHTerminalView.launchConfiguration(
        for: connection,
        credential: nil
    )

    #expect(launch.args.contains("ServerAliveInterval=30"))
    #expect(launch.args.contains("ServerAliveCountMax=3"))
    #expect(launch.args.contains("-J"))
    #expect(launch.args.contains("jump.example.com"))
    #expect(launch.args.contains("-L"))
    #expect(launch.args.contains("127.0.0.1:8080:localhost:80"))
    #expect(launch.args.suffix(5) == [
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-p",
        "2222",
        "deploy@prod.example.com"
    ])
}

@MainActor
@Test func launchArgumentsIncludeDynamicForwardingWithoutDestination() {
    let connection = ConnectionRecord(
        alias: "Proxy",
        host: "proxy.example.com",
        username: "deploy",
        authentication: .password,
        portForwards: [
            .init(
                direction: .dynamic,
                bindAddress: "127.0.0.1",
                localPort: 1080
            )
        ]
    )

    let launch = LocalSSHTerminalView.launchConfiguration(
        for: connection,
        credential: nil
    )

    #expect(launch.args.contains("-D"))
    #expect(launch.args.contains("127.0.0.1:1080"))
}

@Test func pasteConfirmationOnlyTriggersForMultipleLogicalLines() {
    #expect(!LocalSSHTerminalView.needsMultilinePasteConfirmation(""))
    #expect(!LocalSSHTerminalView.needsMultilinePasteConfirmation("ls -la"))
    #expect(!LocalSSHTerminalView.needsMultilinePasteConfirmation("ls -la\n"))
    #expect(LocalSSHTerminalView.needsMultilinePasteConfirmation("cd /tmp\nrm -rf test\n"))
    #expect(LocalSSHTerminalView.needsMultilinePasteConfirmation("cd /tmp\rrm -rf test"))
}
