import Foundation
import Darwin
import SwiftTerm
import TermTPCore

extension LocalSSHTerminalView {
    struct AskPassBundle {
        var directoryPath: String
        var scriptPath: String
        var passwordFilePath: String
    }

    struct LaunchConfiguration {
        var executable: String
        var args: [String]
        var environment: [String]?

        var debugCommand: String {
            ([executable] + args).map(Self.shellQuoted).joined(separator: " ")
        }

        private static func shellQuoted(_ value: String) -> String {
            guard !value.isEmpty else {
                return "''"
            }

            if value.rangeOfCharacter(from: CharacterSet(charactersIn: " \t\n\"'\\$`")) == nil {
                return value
            }

            return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
    }

    static func password(from credential: Credential?) -> String? {
        guard
            case .password(let password) = credential,
            !password.isEmpty
        else {
            return nil
        }

        return password
    }

    static func launchConfiguration(
        for connection: ConnectionRecord,
        credential: Credential?,
        askPass: AskPassBundle? = nil
    ) -> LaunchConfiguration {
        guard needsAskPassScript(for: credential) else {
            return LaunchConfiguration(
                executable: "/bin/launchctl",
                args: launchctlArguments(
                    wrapping: "/usr/bin/ssh",
                    arguments: sshArguments(for: connection, promptsForUnknownHostKey: true)
                ),
                environment: terminalEnvironment(additionalValues: [:])
            )
        }

        let askPass = askPass ?? makeAskPassBundle(password: password(from: credential) ?? "")
        return LaunchConfiguration(
            executable: "/bin/launchctl",
            args: launchctlArguments(
                wrapping: "/usr/bin/ssh",
                arguments: sshArguments(for: connection, promptsForUnknownHostKey: false)
            ),
            environment: terminalEnvironment(additionalValues: [
                "TERMTP_SSH_PASSWORD_FILE": askPass.passwordFilePath,
                "SSH_ASKPASS": askPass.scriptPath,
                "SSH_ASKPASS_REQUIRE": "force",
                "DISPLAY": "termtp:0"
            ])
        )
    }

    static var knownHostsFileURL: URL {
        TermTPKnownHostsFile.defaultFileURL
    }

    static func prepareKnownHostsFile() {
        let directory = knownHostsFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    static func makeAskPassBundle(password: String) -> AskPassBundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termtp-askpass-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        let scriptURL = directory.appendingPathComponent("ssh-askpass.sh")
        let passwordURL = directory.appendingPathComponent("password")
        let script = """
        #!/bin/sh
        IFS= read -r password < "$TERMTP_SSH_PASSWORD_FILE"
        printf '%s\\n' "$password"
        """

        try? password.write(to: passwordURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: passwordURL.path
        )
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
        return AskPassBundle(
            directoryPath: directory.path,
            scriptPath: scriptURL.path,
            passwordFilePath: passwordURL.path
        )
    }

    @available(*, unavailable, renamed: "makeAskPassBundle(password:)")
    static func makeAskPassScriptPath() -> String {
        makeAskPassBundle(password: "").scriptPath
    }

    private static func needsAskPassScript(for credential: Credential?) -> Bool {
        password(from: credential) != nil
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

    private static func sshArguments(
        for connection: ConnectionRecord,
        promptsForUnknownHostKey: Bool
    ) -> [String] {
        var args = [
            "-F", "/dev/null",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "GlobalKnownHostsFile=/dev/null",
            "-o", "UserKnownHostsFile=\(openSSHOptionValue(knownHostsFileURL.path))",
            "-p", String(connection.port),
            "\(connection.username)@\(connection.host)"
        ]

        if promptsForUnknownHostKey {
            if let index = args.firstIndex(of: "StrictHostKeyChecking=accept-new") {
                args[index] = "StrictHostKeyChecking=ask"
            }
        }

        if case .publicKey(let privateKeyPath) = connection.authentication {
            args.insert(contentsOf: ["-i", privateKeyPath], at: 0)
            args.insert(contentsOf: [
                "-o", "IdentitiesOnly=yes",
                "-o", "IdentityAgent=none"
            ], at: 0)
        } else {
            args.insert(contentsOf: [
                "-o", "PreferredAuthentications=password",
                "-o", "PubkeyAuthentication=no",
                "-o", "NumberOfPasswordPrompts=1"
            ], at: 0)
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

    private static func launchctlArguments(
        wrapping executable: String,
        arguments: [String]
    ) -> [String] {
        ["asuser", String(getuid()), executable] + arguments
    }

    static func openSSHOptionValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: " ", with: "\\ ")
            .replacingOccurrences(of: "\t", with: "\\\t")
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
}
