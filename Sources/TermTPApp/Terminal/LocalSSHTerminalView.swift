import AppKit
import Network
import SwiftTerm
import SwiftUI
import TermTPCore

struct LocalSSHTerminalView: NSViewRepresentable {
    let connection: ConnectionRecord
    let credential: Credential?
    var fontSize = 11
    var palette = TerminalPalette.palette(for: .classicGreen)
    var strings = AppStrings(language: .zhHans)
    var pendingCommand: TerminalCommand?
    var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = ProtectedLocalProcessTerminalView(frame: .zero)
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

    static func dismantleNSView(_ terminalView: LocalProcessTerminalView, coordinator: Coordinator) {
        terminalView.terminate()
        coordinator.removeAskPassScript()
    }

    private func configure(_ terminalView: LocalProcessTerminalView) {
        terminalView.autoresizingMask = [.width, .height]
        let font = TerminalFont.make(size: fontSize)
        if terminalView.font.fontName != font.fontName || terminalView.font.pointSize != font.pointSize {
            terminalView.font = font
        }
        terminalView.nativeBackgroundColor = palette.background.nsColor
        terminalView.nativeForegroundColor = palette.foreground.nsColor
        terminalView.caretColor = terminalView.nativeForegroundColor
        terminalView.layer?.backgroundColor = palette.background.nsColor.cgColor
        terminalView.menu = terminalContextMenu(for: terminalView, strings: strings)
        if let protectedTerminalView = terminalView as? ProtectedLocalProcessTerminalView {
            protectedTerminalView.strings = strings
        }
        terminalView.needsDisplay = true
        terminalView.setNeedsDisplay(terminalView.bounds)
        terminalView.displayIfNeeded()
    }

    private func startSSH(in terminalView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startedConnectionID = connection.id
        context.coordinator.removeAskPassScript()
        Self.prepareKnownHostsFile()
        let askPass = Self.password(from: credential).map(Self.makeAskPassBundle)
        context.coordinator.askPassDirectoryPath = askPass?.directoryPath
        let launch = Self.launchConfiguration(
            for: connection,
            credential: credential,
            askPass: askPass
        )
        Self.writeDebugLog(for: connection, launch: launch)
        terminalView.feed(text: "TermTP SSH: \(launch.debugCommand)\r\n")
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment
        )
        context.coordinator.onCommandHandled = onCommandHandled
        context.coordinator.lastSentCommandID = nil
    }

    private static func writeDebugLog(
        for connection: ConnectionRecord,
        launch: LaunchConfiguration
    ) {
        let logURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
            .appendingPathComponent("ssh-debug.log")
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let localNetworkProbe = LocalNetworkProbe.run(
            host: connection.host,
            port: connection.port
        )
        let route = ProcessRunner.run(
            executable: "/sbin/route",
            arguments: ["-n", "get", connection.host]
        )
        let nc = ProcessRunner.run(
            executable: "/usr/bin/nc",
            arguments: ["-vz", "-G", "3", connection.host, String(connection.port)]
        )
        let ncWithoutConnectX = ProcessRunner.run(
            executable: "/usr/bin/nc",
            arguments: ["-vz", "-G", "3", "-O", connection.host, String(connection.port)]
        )

        let environment = launch.environment?.joined(separator: "\n") ?? "<default>"
        let entry = """

        === \(Date()) ===
        target: \(connection.username)@\(connection.host):\(connection.port)
        command: \(launch.debugCommand)
        args: \(([launch.executable] + launch.args).joined(separator: "\n"))
        environment:
        \(environment)
        local-network-probe:
        \(localNetworkProbe)
        route:
        \(route)
        port-check:
        \(nc)
        port-check-without-connectx:
        \(ncWithoutConnectX)

        """

        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logURL, options: [.atomic])
            }
        }
    }

    private enum LocalNetworkProbe {
        static func run(host: String, port: UInt16) -> String {
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                return "invalid port: \(port)"
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: endpointPort,
                using: .tcp
            )
            let queue = DispatchQueue(label: "local.termtp.local-network-probe")
            let semaphore = DispatchSemaphore(value: 0)
            let stateLog = StateLog()

            connection.stateUpdateHandler = { state in
                stateLog.append(String(describing: state))

                switch state {
                case .ready, .failed, .cancelled:
                    semaphore.signal()
                default:
                    break
                }
            }

            connection.start(queue: queue)
            let waitResult = semaphore.wait(timeout: .now() + 3)
            connection.cancel()

            let output = stateLog.output()

            if waitResult == .timedOut {
                return "\(output)\n<timeout waiting for local network probe>"
            }

            return output
        }

        private final class StateLog: @unchecked Sendable {
            private let lock = NSLock()
            private var states: [String] = []

            func append(_ state: String) {
                lock.lock()
                states.append(state)
                lock.unlock()
            }

            func output() -> String {
                lock.lock()
                defer { lock.unlock() }
                return states.isEmpty ? "<no state updates>" : states.joined(separator: "\n")
            }
        }
    }

    private enum ProcessRunner {
        static func run(executable: String, arguments: [String]) -> String {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                return output.isEmpty ? "<empty>" : output
            } catch {
                return String(describing: error)
            }
        }
    }

    final class Coordinator {
        var startedConnectionID: ConnectionRecord.ID?
        var askPassDirectoryPath: String?
        var lastSentCommandID: TerminalCommand.ID?
        var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }

        deinit {
            removeAskPassScript()
        }

        func removeAskPassScript() {
            guard let askPassDirectoryPath else {
                return
            }

            try? FileManager.default.removeItem(atPath: askPassDirectoryPath)
            self.askPassDirectoryPath = nil
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
