import AppKit
import SwiftTerm
import SwiftUI
import TermCCore

struct LocalSSHTerminalView: NSViewRepresentable {
    let connection: ConnectionRecord
    let credential: Credential?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        configure(terminalView)
        startSSH(in: terminalView, context: context)
        return terminalView
    }

    func updateNSView(_ terminalView: LocalProcessTerminalView, context: Context) {
        configure(terminalView)
        guard context.coordinator.startedConnectionID != connection.id else {
            return
        }

        terminalView.terminate()
        startSSH(in: terminalView, context: context)
    }

    private func configure(_ terminalView: LocalProcessTerminalView) {
        terminalView.autoresizingMask = [.width, .height]
        terminalView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = NSColor(
            calibratedRed: 0.45,
            green: 1.0,
            blue: 0.55,
            alpha: 1.0
        )
        terminalView.caretColor = terminalView.nativeForegroundColor
        terminalView.layer?.backgroundColor = NSColor.black.cgColor
        terminalView.menu = terminalContextMenu(for: terminalView)
    }

    private func startSSH(in terminalView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startedConnectionID = connection.id
        let launch = launchConfiguration(for: connection, credential: credential)
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment
        )
    }

    private func launchConfiguration(
        for connection: ConnectionRecord,
        credential: Credential?
    ) -> (executable: String, args: [String], environment: [String]?) {
        guard
            case .password(let password) = credential,
            !password.isEmpty
        else {
            return ("/usr/bin/ssh", sshArguments(for: connection), nil)
        }

        return (
            "/usr/bin/ssh",
            sshArguments(for: connection),
            [
                "TERMTP_SSH_PASSWORD=\(password)",
                "SSH_ASKPASS=\(askPassScriptPath())",
                "SSH_ASKPASS_REQUIRE=force",
                "DISPLAY=termtp:0"
            ]
        )
    }

    private func askPassScriptPath() -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("termtp-ssh-askpass.sh")
        let script = """
        #!/bin/sh
        printf '%s\\n' "$TERMTP_SSH_PASSWORD"
        """

        try? script.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
        return url.path
    }

    private func terminalContextMenu(for terminalView: LocalProcessTerminalView) -> NSMenu {
        let menu = NSMenu()
        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(LocalProcessTerminalView.copy(_:)),
            keyEquivalent: ""
        )
        copyItem.target = terminalView
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: "Paste",
            action: #selector(LocalProcessTerminalView.paste(_:)),
            keyEquivalent: ""
        )
        pasteItem.target = terminalView
        menu.addItem(pasteItem)
        return menu
    }

    private func sshArguments(for connection: ConnectionRecord) -> [String] {
        var args = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-p", String(connection.port),
            "\(connection.username)@\(connection.host)"
        ]

        if case .publicKey(let privateKeyPath) = connection.authentication {
            args.insert(contentsOf: ["-i", privateKeyPath], at: 0)
        }

        return args
    }

    final class Coordinator {
        var startedConnectionID: ConnectionRecord.ID?
    }
}
