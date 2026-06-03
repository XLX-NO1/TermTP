import AppKit
import Network
import SwiftTerm
import SwiftUI
import TermTPCore

struct LocalSSHTerminalView: NSViewRepresentable {
    let tabID: TerminalTab.ID
    let runID: UUID?
    let connection: ConnectionRecord
    let credential: Credential?
    var fontSize = 11
    var palette = TerminalPalette.palette(for: .classicGreen)
    var strings = AppStrings(language: .zhHans)
    var pendingCommand: TerminalCommand?
    var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }
    var onProcessStarted: (LocalSSHProcessStarted) -> Void = { _ in }
    var onProcessExit: (LocalSSHProcessExit) -> Void = { _ in }

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
        let nextIdentity = SSHTerminalSessionIdentity(connectionID: connection.id, runID: runID)
        guard context.coordinator.sessionIdentity != nextIdentity else {
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
        context.coordinator.sessionIdentity = SSHTerminalSessionIdentity(connectionID: connection.id, runID: runID)
        context.coordinator.removeAskPassScript()
        Self.prepareKnownHostsFile()
        let localNetworkProbe = LocalSSHDebugLogger.LocalNetworkProbe.run(
            host: connection.host,
            port: connection.port,
            timeout: 1.5
        )
        let askPass = Self.password(from: credential).map(Self.makeAskPassBundle)
        context.coordinator.askPassDirectoryPath = askPass?.directoryPath
        let launch = Self.launchConfiguration(
            for: connection,
            credential: credential,
            askPass: askPass
        )
        terminalView.feed(text: "TermTP SSH: \(launch.debugCommand)\r\n")
        if localNetworkProbe.indicatesLocalNetworkFailure {
            terminalView.feed(text: "TermTP 提示: 当前 App 局域网探测失败，macOS 可能未允许 TermTP 访问本地网络，或目标主机暂时不可达。\r\n")
            terminalView.feed(text: "TermTP 探测: \(localNetworkProbe.summary.replacingOccurrences(of: "\n", with: " | "))\r\n")
        }
        context.coordinator.tabID = tabID
        context.coordinator.runID = runID
        context.coordinator.connection = connection
        context.coordinator.launch = launch.snapshot
        context.coordinator.onProcessStarted = onProcessStarted
        context.coordinator.onProcessExit = onProcessExit
        terminalView.processDelegate = context.coordinator
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment
        )
        onProcessStarted(LocalSSHProcessStarted(tabID: tabID, runID: runID, connection: connection))
        context.coordinator.onCommandHandled = onCommandHandled
        context.coordinator.lastSentCommandID = nil
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var tabID: TerminalTab.ID?
        var runID: UUID?
        var connection: ConnectionRecord?
        var launch: LocalSSHLaunchSnapshot?
        var sessionIdentity: SSHTerminalSessionIdentity?
        var askPassDirectoryPath: String?
        var lastSentCommandID: TerminalCommand.ID?
        var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }
        var onProcessStarted: (LocalSSHProcessStarted) -> Void = { _ in }
        var onProcessExit: (LocalSSHProcessExit) -> Void = { _ in }

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

        func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
            removeAskPassScript()
            guard let tabID, let connection, let launch else {
                return
            }

            onProcessExit(
                LocalSSHProcessExit(
                    tabID: tabID,
                    runID: self.runID,
                    connection: connection,
                    exitCode: exitCode,
                    launch: launch
                )
            )
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

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

enum LocalSSHDebugLogger {
    static func writeDebugLog(for exit: LocalSSHProcessExit) {
        let logURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
            .appendingPathComponent("ssh-debug.log")
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let diagnostics = diagnostics(for: exit)

        let environment = exit.launch.environment?.joined(separator: "\n") ?? "<default>"
        let entry = """

        === \(Date()) ===
        target: \(exit.connection.username)@\(exit.connection.host):\(exit.connection.port)
        exit-code: \(exit.normalizedExitCode.map(String.init) ?? "<unknown>")
        raw-exit-code: \(exit.exitCode.map(String.init) ?? "<unknown>")
        command: \(exit.launch.debugCommand)
        args: \(([exit.launch.executable] + exit.launch.args).joined(separator: "\n"))
        environment:
        \(environment)
        \(diagnostics)

        """

        if let data = entry.data(using: .utf8) {
            rotateDebugLogIfNeeded(at: logURL, incomingByteCount: data.count)
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

    private static func diagnostics(for exit: LocalSSHProcessExit) -> String {
        guard exit.normalizedExitCode != 0 else {
            return "diagnostics: skipped for clean exit"
        }

        let localNetworkProbe = LocalNetworkProbe.run(
            host: exit.connection.host,
            port: exit.connection.port,
            timeout: 3
        )
        let route = ProcessRunner.run(
            executable: "/sbin/route",
            arguments: ["-n", "get", exit.connection.host],
            timeout: 3
        )
        let nc = ProcessRunner.run(
            executable: "/usr/bin/nc",
            arguments: ["-vz", "-G", "3", exit.connection.host, String(exit.connection.port)],
            timeout: 4
        )
        let ncWithoutConnectX = ProcessRunner.run(
            executable: "/usr/bin/nc",
            arguments: ["-vz", "-G", "3", "-O", exit.connection.host, String(exit.connection.port)],
            timeout: 4
        )

        return """
        local-network-probe:
        \(localNetworkProbe.summary)
        route:
        \(route)
        port-check:
        \(nc)
        port-check-without-connectx:
        \(ncWithoutConnectX)
        """
    }

    static func rotateDebugLogIfNeeded(at logURL: URL, incomingByteCount: Int) {
        let maxBytes = 512 * 1024
        let currentSize = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard currentSize + incomingByteCount > maxBytes else {
            return
        }

        let archiveURL = logURL.deletingLastPathComponent().appendingPathComponent("ssh-debug.previous.log")
        try? FileManager.default.removeItem(at: archiveURL)
        try? FileManager.default.moveItem(at: logURL, to: archiveURL)
    }

    enum LocalNetworkProbe {
        struct Result {
            var states: [String]
            var timedOut: Bool

            var summary: String {
                var output = states.isEmpty ? "<no state updates>" : states.joined(separator: "\n")
                if timedOut {
                    output += "\n<timeout waiting for local network probe>"
                }
                return output
            }

            var indicatesLocalNetworkFailure: Bool {
                summary.contains("Network is down") || summary.contains("POSIXErrorCode(rawValue: 50)")
            }
        }

        static func run(host: String, port: UInt16, timeout: TimeInterval) -> Result {
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                return Result(states: ["invalid port: \(port)"], timedOut: false)
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
            let waitResult = semaphore.wait(timeout: .now() + .milliseconds(Int(timeout * 1000)))
            connection.cancel()

            return Result(states: stateLog.snapshot(), timedOut: waitResult == .timedOut)
        }

        private final class StateLog: @unchecked Sendable {
            private let lock = NSLock()
            private var states: [String] = []

            func append(_ state: String) {
                lock.lock()
                states.append(state)
                lock.unlock()
            }

            func snapshot() -> [String] {
                lock.lock()
                defer { lock.unlock() }
                return states
            }
        }
    }

    private enum ProcessRunner {
        static func run(executable: String, arguments: [String], timeout: TimeInterval) -> String {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    if process.isRunning {
                        process.interrupt()
                    }
                    return "<timeout after \(timeout)s>"
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                return output.isEmpty ? "<empty>" : output
            } catch {
                return String(describing: error)
            }
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

    func processExit(_ onExit: @escaping (LocalSSHProcessExit) -> Void) -> LocalSSHTerminalView {
        var view = self
        view.onProcessExit = onExit
        return view
    }

    func processStarted(_ onStarted: @escaping (LocalSSHProcessStarted) -> Void) -> LocalSSHTerminalView {
        var view = self
        view.onProcessStarted = onStarted
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
