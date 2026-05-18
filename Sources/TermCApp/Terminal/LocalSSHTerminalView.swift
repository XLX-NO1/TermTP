import AppKit
import SwiftTerm
import SwiftUI
import TermCCore

struct LocalSSHTerminalView: NSViewRepresentable {
    let connection: ConnectionRecord
    let credential: Credential?
    var fontSize: Double = 11
    var palette = TerminalPalette.palette(for: .classicGreen)
    var strings = AppStrings(language: .zhHans)
    var pendingCommand: TerminalCommand?
    var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }

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
        context.coordinator.onCommandHandled = onCommandHandled
        guard context.coordinator.startedConnectionID != connection.id else {
            context.coordinator.sendPendingCommandIfNeeded(pendingCommand, to: terminalView)
            return
        }

        terminalView.terminate()
        startSSH(in: terminalView, context: context)
        context.coordinator.sendPendingCommandIfNeeded(pendingCommand, to: terminalView)
    }

    private func configure(_ terminalView: LocalProcessTerminalView) {
        terminalView.autoresizingMask = [.width, .height]
        terminalView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.nativeBackgroundColor = palette.background.nsColor
        terminalView.nativeForegroundColor = palette.foreground.nsColor
        terminalView.caretColor = terminalView.nativeForegroundColor
        terminalView.layer?.backgroundColor = palette.background.nsColor.cgColor
        terminalView.menu = terminalContextMenu(for: terminalView, strings: strings)
        terminalView.needsDisplay = true
        terminalView.setNeedsDisplay(terminalView.bounds)
    }

    private func startSSH(in terminalView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startedConnectionID = connection.id
        context.coordinator.removeAskPassScript()
        let askPassScriptPath = Self.needsAskPassScript(for: credential)
            ? Self.makeAskPassScriptPath()
            : nil
        context.coordinator.askPassScriptPath = askPassScriptPath
        let launch = Self.launchConfiguration(
            for: connection,
            credential: credential,
            askPassScriptPath: askPassScriptPath
        )
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment
        )
        context.coordinator.onCommandHandled = onCommandHandled
        context.coordinator.lastSentCommandID = nil
    }

    private static func needsAskPassScript(for credential: Credential?) -> Bool {
        guard case .password(let password) = credential else {
            return false
        }

        return !password.isEmpty
    }

    struct LaunchConfiguration {
        var executable: String
        var args: [String]
        var environment: [String]?
    }

    static func launchConfiguration(
        for connection: ConnectionRecord,
        credential: Credential?,
        askPassScriptPath: String? = nil
    ) -> LaunchConfiguration {
        guard
            case .password(let password) = credential,
            !password.isEmpty
        else {
            return LaunchConfiguration(
                executable: "/usr/bin/ssh",
                args: sshArguments(for: connection),
                environment: nil
            )
        }

        return LaunchConfiguration(
            executable: "/usr/bin/ssh",
            args: sshArguments(for: connection),
            environment: terminalEnvironment(additionalValues: [
                "TERMTP_SSH_PASSWORD": password,
                "SSH_ASKPASS": askPassScriptPath ?? makeAskPassScriptPath(),
                "SSH_ASKPASS_REQUIRE": "force",
                "DISPLAY": "termtp:0"
            ])
        )
    }

    private static func terminalEnvironment(additionalValues: [String: String]) -> [String] {
        var values: [String: String] = [:]
        for entry in Terminal.getEnvironmentVariables(termName: "xterm-256color") {
            guard let separator = entry.firstIndex(of: "=") else {
                continue
            }

            values[String(entry[..<separator])] = String(entry[entry.index(after: separator)...])
        }

        additionalValues.forEach { key, value in
            values[key] = value
        }

        return values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
    }

    static func makeAskPassScriptPath() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termtp-askpass-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("ssh-askpass.sh")
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

    private func terminalContextMenu(for terminalView: LocalProcessTerminalView, strings: AppStrings) -> NSMenu {
        let menu = NSMenu()
        let copyItem = NSMenuItem(
            title: strings.copy,
            action: #selector(LocalProcessTerminalView.copy(_:)),
            keyEquivalent: ""
        )
        copyItem.target = terminalView
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: strings.paste,
            action: #selector(LocalProcessTerminalView.paste(_:)),
            keyEquivalent: ""
        )
        pasteItem.target = terminalView
        menu.addItem(pasteItem)
        return menu
    }

    private static func sshArguments(for connection: ConnectionRecord) -> [String] {
        var args = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-p", String(connection.port),
            "\(connection.username)@\(connection.host)"
        ]

        if case .publicKey(let privateKeyPath) = connection.authentication {
            args.insert(contentsOf: ["-i", privateKeyPath], at: 0)
        }

        if connection.keepAlive.isEnabled {
            args.insert(contentsOf: [
                "-o", "ServerAliveInterval=\(connection.keepAlive.intervalSeconds)",
                "-o", "ServerAliveCountMax=\(connection.keepAlive.maxCount)"
            ], at: 0)
        }

        if let jumpHost = connection.jumpHost, !jumpHost.isEmpty {
            args.insert(contentsOf: ["-J", jumpHost], at: 0)
        }

        for forward in connection.portForwards.reversed() {
            args.insert(contentsOf: sshArguments(for: forward), at: 0)
        }

        return args
    }

    private static func sshArguments(for forward: ConnectionRecord.PortForward) -> [String] {
        switch forward.direction {
        case .local:
            let bind = forward.bindAddress.isEmpty ? "" : "\(forward.bindAddress):"
            return [
                "-L",
                "\(bind)\(forward.localPort):\(forward.destinationHost):\(forward.destinationPort)"
            ]
        case .remote:
            let bind = forward.bindAddress.isEmpty ? "" : "\(forward.bindAddress):"
            return [
                "-R",
                "\(bind)\(forward.localPort):\(forward.destinationHost):\(forward.destinationPort)"
            ]
        case .dynamic:
            let bind = forward.bindAddress.isEmpty ? "" : "\(forward.bindAddress):"
            return ["-D", "\(bind)\(forward.localPort)"]
        }
    }

    final class Coordinator {
        var startedConnectionID: ConnectionRecord.ID?
        var askPassScriptPath: String?
        var lastSentCommandID: TerminalCommand.ID?
        var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }

        deinit {
            removeAskPassScript()
        }

        func removeAskPassScript() {
            guard let askPassScriptPath else {
                return
            }

            let scriptURL = URL(fileURLWithPath: askPassScriptPath)
            try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent())
            self.askPassScriptPath = nil
        }

        @MainActor
        func sendPendingCommandIfNeeded(
            _ command: TerminalCommand?,
            to terminalView: LocalProcessTerminalView
        ) {
            guard
                let command,
                lastSentCommandID != command.id
            else {
                return
            }

            let bytes = Array(command.text.utf8)
            lastSentCommandID = command.id
            terminalView.process.send(data: bytes[...])
            onCommandHandled(command.id)
        }
    }
}

extension LocalSSHTerminalView {
    func pendingCommand(
        _ command: TerminalCommand?,
        onHandled: @escaping (TerminalCommand.ID) -> Void
    ) -> LocalSSHTerminalView {
        var view = self
        view.pendingCommand = command
        view.onCommandHandled = onHandled
        return view
    }

    func localized(_ strings: AppStrings) -> LocalSSHTerminalView {
        var view = self
        view.strings = strings
        return view
    }

    func themed(_ palette: TerminalPalette) -> LocalSSHTerminalView {
        var view = self
        view.palette = palette
        return view
    }
}
