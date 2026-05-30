import Foundation
import Testing
import TermTPCore
@testable import TermTPApp

@MainActor
@Test func passwordLaunchEnvironmentKeepsTermVariable() {
    let askPassScriptPath = "/tmp/termtp-test-askpass.sh"
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: Credential.password("secret"),
        askPass: .init(
            directoryPath: "/tmp/termtp-test-askpass",
            scriptPath: askPassScriptPath,
            passwordFilePath: "/tmp/termtp-test-askpass/password"
        )
    )

    #expect(launch.environment?.contains("TERM=xterm-256color") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS_REQUIRE=force") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS=\(askPassScriptPath)") == true)
    #expect(launch.environment?.contains("TERMTP_SSH_PASSWORD=secret") == false)
    #expect(launch.environment?.contains("TERMTP_SSH_PASSWORD_FILE=/tmp/termtp-test-askpass/password") == true)
    #expect(launch.args.contains("StrictHostKeyChecking=accept-new"))
    #expect(launch.args.contains("-F"))
    #expect(launch.args.contains("/dev/null"))
    #expect(launch.args.contains("GlobalKnownHostsFile=/dev/null"))
    #expect(launch.args.contains("PreferredAuthentications=password"))
    #expect(launch.args.contains("PubkeyAuthentication=no"))
    #expect(launch.args.contains("NumberOfPasswordPrompts=1"))
}

@MainActor
@Test func manualPasswordLaunchEnvironmentKeepsTermVariable() {
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: nil
    )

    #expect(launch.environment?.contains("TERM=xterm-256color") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS_REQUIRE=force") == false)
}

@MainActor
@Test func askPassBundleUsesIsolatedTemporaryDirectoryAndRestrictedPasswordFile() throws {
    let first = LocalSSHTerminalView.makeAskPassBundle(password: "first-secret")
    let second = LocalSSHTerminalView.makeAskPassBundle(password: "second-secret")

    #expect(first.scriptPath != second.scriptPath)
    #expect(URL(fileURLWithPath: first.scriptPath).lastPathComponent == "ssh-askpass.sh")
    #expect(URL(fileURLWithPath: first.passwordFilePath).lastPathComponent == "password")
    #expect(FileManager.default.isExecutableFile(atPath: first.scriptPath))
    #expect(try String(contentsOfFile: first.passwordFilePath, encoding: .utf8) == "first-secret")

    let scriptPermissions = try FileManager.default.attributesOfItem(atPath: first.scriptPath)[.posixPermissions] as? Int
    let passwordPermissions = try FileManager.default.attributesOfItem(atPath: first.passwordFilePath)[.posixPermissions] as? Int
    #expect(scriptPermissions == 0o700)
    #expect(passwordPermissions == 0o600)

    try? FileManager.default.removeItem(atPath: first.directoryPath)
    try? FileManager.default.removeItem(atPath: second.directoryPath)
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
    #expect(launch.args.suffix(11) == [
        "-F",
        "/dev/null",
        "-o",
        "StrictHostKeyChecking=ask",
        "-o",
        "GlobalKnownHostsFile=/dev/null",
        "-o",
        "UserKnownHostsFile=\(LocalSSHTerminalView.openSSHOptionValue(LocalSSHTerminalView.knownHostsFileURL.path))",
        "-p",
        "2222",
        "deploy@prod.example.com"
    ])
}

@MainActor
@Test func manualLaunchArgumentsAskBeforeSavingUnknownHostKeyAndUseTermTPKnownHostsFile() {
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: nil
    )

    #expect(launch.args.suffix(13) == [
        "-F",
        "/dev/null",
        "-o",
        "StrictHostKeyChecking=ask",
        "-o",
        "GlobalKnownHostsFile=/dev/null",
        "-o",
        "UserKnownHostsFile=\(LocalSSHTerminalView.openSSHOptionValue(LocalSSHTerminalView.knownHostsFileURL.path))",
        "-o",
        "ProxyCommand=/usr/bin/nc -O %h %p",
        "-p",
        "22",
        "me@localhost"
    ])
}

@MainActor
@Test func passwordLaunchArgumentsDoNotUseSystemSSHIdentitySources() {
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: Credential.password("secret")
    )

    #expect(launch.args.contains("-F"))
    #expect(launch.args.contains("/dev/null"))
    #expect(launch.args.contains("GlobalKnownHostsFile=/dev/null"))
    #expect(launch.args.contains("UserKnownHostsFile=\(LocalSSHTerminalView.openSSHOptionValue(LocalSSHTerminalView.knownHostsFileURL.path))"))
    #expect(launch.args.contains("ProxyCommand=/usr/bin/nc -O %h %p"))
    #expect(launch.args.contains("PreferredAuthentications=password"))
    #expect(launch.args.contains("PubkeyAuthentication=no"))
    #expect(!launch.args.contains("IdentityAgent=none"))
}

@MainActor
@Test func launchDebugCommandShellQuotesArguments() {
    let launch = LocalSSHTerminalView.LaunchConfiguration(
        executable: "/usr/bin/ssh",
        args: [
            "-o",
            "UserKnownHostsFile=/Users/me/Library/Application\\ Support/TermTP/known_hosts",
            "root@192.168.3.55"
        ],
        environment: nil
    )

    #expect(launch.debugCommand.contains("'UserKnownHostsFile=/Users/me/Library/Application\\ Support/TermTP/known_hosts'"))
    #expect(launch.debugCommand.hasSuffix("root@192.168.3.55"))
}

@MainActor
@Test func launchArgumentsEscapeOpenSSHOptionValuesWithSpaces() {
    #expect(LocalSSHTerminalView.openSSHOptionValue("/Users/me/Library/Application Support/TermTP/known_hosts") == "/Users/me/Library/Application\\ Support/TermTP/known_hosts")
}

@MainActor
@Test func removeKnownHostsEntryKeepsOtherPortsAndHosts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("known_hosts")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try """
    example.com ssh-ed25519 AAAATEST
    [example.com]:2222 ssh-ed25519 AAAAPORT
    other.example.com ssh-ed25519 AAAAOTHER

    """.write(to: url, atomically: true, encoding: .utf8)

    try TermTPKnownHostsFile.removeEntry(host: "example.com", port: 22, from: url)

    let knownHosts = try String(contentsOf: url, encoding: .utf8)
    #expect(!knownHosts.contains("example.com ssh-ed25519 AAAATEST"))
    #expect(knownHosts.contains("[example.com]:2222 ssh-ed25519 AAAAPORT"))
    #expect(knownHosts.contains("other.example.com ssh-ed25519 AAAAOTHER"))
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
