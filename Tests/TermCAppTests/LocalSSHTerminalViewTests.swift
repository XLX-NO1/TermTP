import Testing
import TermCCore
@testable import TermCApp

@MainActor
@Test func passwordLaunchEnvironmentKeepsTermVariable() {
    let launch = LocalSSHTerminalView.launchConfiguration(
        for: ConnectionRecord.samplePassword,
        credential: Credential.password("secret")
    )

    #expect(launch.environment?.contains("TERM=xterm-256color") == true)
    #expect(launch.environment?.contains("SSH_ASKPASS_REQUIRE=force") == true)
}
