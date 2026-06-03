import AppKit
@preconcurrency import Citadel
@preconcurrency import NIOCore
@preconcurrency import NIOSSH
import SwiftTerm
import SwiftUI
import TermTPCore

struct SSHTerminalSessionIdentity: Hashable {
    var connectionID: ConnectionRecord.ID
    var runID: UUID?
}

@available(macOS 15.0, *)
struct EmbeddedSSHTerminalView: NSViewRepresentable {
    let tabID: TerminalTab.ID
    let runID: UUID?
    let connection: ConnectionRecord
    let credential: Credential?
    let hostKeyTrustStore: any HostKeyTrusting
    var fontSize = 11
    var palette = TerminalPalette.palette(for: .classicGreen)
    var strings = AppStrings(language: .zhHans)
    var pendingCommand: TerminalCommand?
    var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }
    var onProcessStarted: @Sendable (LocalSSHProcessStarted) -> Void = { _ in }
    var onProcessExit: @Sendable (LocalSSHProcessExit) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let terminalView = SwiftTerm.TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        configure(terminalView)
        syncSession(in: terminalView, context: context)
        return terminalView
    }

    func updateNSView(_ terminalView: SwiftTerm.TerminalView, context: Context) {
        configure(terminalView)
        context.coordinator.onCommandHandled = onCommandHandled
        syncSession(in: terminalView, context: context)
        context.coordinator.sendPendingCommandIfNeeded(pendingCommand)
    }

    static func dismantleNSView(_ terminalView: SwiftTerm.TerminalView, coordinator: Coordinator) {
        coordinator.stop()
    }

    private func configure(_ terminalView: SwiftTerm.TerminalView) {
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
        terminalView.needsDisplay = true
        terminalView.setNeedsDisplay(terminalView.bounds)
        terminalView.displayIfNeeded()
    }

    private func syncSession(in terminalView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.start(
            tabID: tabID,
            runID: runID,
            connection: connection,
            credential: credential,
            hostKeyTrustStore: hostKeyTrustStore,
            terminalView: terminalView,
            onProcessStarted: onProcessStarted,
            onProcessExit: onProcessExit
        )
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor TerminalViewDelegate {
        private var sessionIdentity: SSHTerminalSessionIdentity?
        private var terminalTask: Task<Void, Never>?
        private var clientBox: EmbeddedSSHClientBox?
        private var writer: SendableTTYWriter?
        private var lastSentCommandID: TerminalCommand.ID?
        var onCommandHandled: (TerminalCommand.ID) -> Void = { _ in }

        func start(
            tabID: TerminalTab.ID,
            runID: UUID?,
            connection: ConnectionRecord,
            credential: Credential?,
            hostKeyTrustStore: any HostKeyTrusting,
            terminalView: SwiftTerm.TerminalView,
            onProcessStarted: @escaping @Sendable (LocalSSHProcessStarted) -> Void,
            onProcessExit: @escaping @Sendable (LocalSSHProcessExit) -> Void
        ) {
            let nextIdentity = SSHTerminalSessionIdentity(connectionID: connection.id, runID: runID)
            guard sessionIdentity != nextIdentity else {
                return
            }

            stop()
            sessionIdentity = nextIdentity
            terminalView.feed(text: "TermTP embedded SSH: \(connection.username)@\(connection.host):\(connection.port)\r\n")

            let cols = max(terminalView.getTerminal().cols, 80)
            let rows = max(terminalView.getTerminal().rows, 24)
            let clientBox = EmbeddedSSHClientBox()
            self.clientBox = clientBox

            terminalTask = Task {
                do {
                    try await EmbeddedSSHRunner.run(
                        connection: connection,
                        credential: credential,
                        hostKeyTrustStore: hostKeyTrustStore,
                        clientBox: clientBox,
                        cols: cols,
                        rows: rows,
                        onWriterReady: { writer in
                            Task { @MainActor in
                                guard self.sessionIdentity == nextIdentity else {
                                    return
                                }

                                self.writer = writer
                                onProcessStarted(LocalSSHProcessStarted(tabID: tabID, runID: runID, connection: connection))
                            }
                        },
                        onOutput: { text in
                            Task { @MainActor in
                                guard self.sessionIdentity == nextIdentity else {
                                    return
                                }

                                terminalView.feed(text: text)
                            }
                        }
                    )
                    await MainActor.run {
                        guard self.sessionIdentity == nextIdentity else {
                            return
                        }

                        onProcessExit(LocalSSHProcessExit(
                            tabID: tabID,
                            runID: runID,
                            connection: connection,
                            exitCode: 0,
                            launch: LocalSSHLaunchSnapshot(
                                executable: "embedded-citadel",
                                args: ["\(connection.username)@\(connection.host)", "-p", String(connection.port)],
                                environment: nil,
                                debugCommand: "embedded-citadel \(connection.username)@\(connection.host):\(connection.port)"
                            )
                        ))
                    }
                } catch {
                    await MainActor.run {
                        guard self.sessionIdentity == nextIdentity else {
                            return
                        }

                        terminalView.feed(text: "\r\nTermTP embedded SSH failed: \(String(describing: error))\r\n")
                        onProcessExit(LocalSSHProcessExit(
                            tabID: tabID,
                            runID: runID,
                            connection: connection,
                            exitCode: 255,
                            launch: LocalSSHLaunchSnapshot(
                                executable: "embedded-citadel",
                                args: ["\(connection.username)@\(connection.host)", "-p", String(connection.port)],
                                environment: nil,
                                debugCommand: "embedded-citadel \(connection.username)@\(connection.host):\(connection.port)"
                            )
                        ))
                    }
                }
            }
        }

        func stop() {
            terminalTask?.cancel()
            terminalTask = nil
            let currentClientBox = clientBox
            Task {
                await currentClientBox?.close()
            }
            self.clientBox = nil
            writer = nil
            sessionIdentity = nil
        }

        func sendPendingCommandIfNeeded(_ command: TerminalCommand?) {
            guard let command, lastSentCommandID != command.id else {
                return
            }

            guard send(bytes: Array(command.text.utf8)) else {
                return
            }

            lastSentCommandID = command.id
            onCommandHandled(command.id)
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            guard let writer else {
                return
            }

            Task {
                try? await writer.changeSize(
                    cols: max(newCols, 1),
                    rows: max(newRows, 1),
                    pixelWidth: 0,
                    pixelHeight: 0
                )
            }
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            send(bytes: Array(data))
        }

        @discardableResult
        private func send(bytes: [UInt8]) -> Bool {
            guard let writer else {
                return false
            }

            Task {
                var buffer = ByteBuffer()
                buffer.writeBytes(bytes)
                try? await writer.write(buffer)
            }
            return true
        }
    }

    private func terminalContextMenu(for terminalView: SwiftTerm.TerminalView, strings: AppStrings) -> NSMenu {
        let menu = NSMenu()
        let copyItem = NSMenuItem(
            title: strings.copy,
            action: #selector(SwiftTerm.TerminalView.copy(_:)),
            keyEquivalent: ""
        )
        copyItem.target = terminalView
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: strings.paste,
            action: #selector(SwiftTerm.TerminalView.paste(_:)),
            keyEquivalent: ""
        )
        pasteItem.target = terminalView
        menu.addItem(pasteItem)
        return menu
    }
}

@available(macOS 15.0, *)
private enum EmbeddedSSHRunner {
    static func run(
        connection: ConnectionRecord,
        credential: Credential?,
        hostKeyTrustStore: any HostKeyTrusting,
        clientBox: EmbeddedSSHClientBox,
        cols: Int,
        rows: Int,
        onWriterReady: @escaping @Sendable (SendableTTYWriter) -> Void,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws {
        let client = try await CitadelSSHClient(
            hostKeyPolicy: .strict,
            hostKeyTrustStore: hostKeyTrustStore
        ).makeClient(record: connection, credential: credential)
        await clientBox.set(client)
        defer {
            Task {
                await clientBox.close()
            }
        }

        let request = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )

        try await client.withPTY(request) { inbound, outbound in
            onWriterReady(SendableTTYWriter(outbound))

            for try await output in inbound {
                switch output {
                case .stdout(let buffer), .stderr(let buffer):
                    onOutput(String(buffer: buffer))
                }
            }
        }
    }
}

@available(macOS 15.0, *)
private actor EmbeddedSSHClientBox {
    private var client: SSHClient?

    func set(_ client: SSHClient) {
        self.client = client
    }

    func close() async {
        guard let client else {
            return
        }

        self.client = nil
        try? await client.close()
    }
}

@available(macOS 15.0, *)
private struct SendableTTYWriter: @unchecked Sendable {
    private let writer: TTYStdinWriter

    init(_ writer: TTYStdinWriter) {
        self.writer = writer
    }

    func write(_ buffer: ByteBuffer) async throws {
        try await writer.write(buffer)
    }

    func changeSize(cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) async throws {
        try await writer.changeSize(
            cols: cols,
            rows: rows,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
    }
}

@available(macOS 15.0, *)
extension EmbeddedSSHTerminalView {
    func pendingCommand(
        _ command: TerminalCommand?,
        onHandled: @escaping (TerminalCommand.ID) -> Void
    ) -> EmbeddedSSHTerminalView {
        var view = self
        view.pendingCommand = command
        view.onCommandHandled = onHandled
        return view
    }

    func processStarted(_ onStarted: @escaping @Sendable (LocalSSHProcessStarted) -> Void) -> EmbeddedSSHTerminalView {
        var view = self
        view.onProcessStarted = onStarted
        return view
    }

    func processExit(_ onExit: @escaping @Sendable (LocalSSHProcessExit) -> Void) -> EmbeddedSSHTerminalView {
        var view = self
        view.onProcessExit = onExit
        return view
    }

    func localized(_ strings: AppStrings) -> EmbeddedSSHTerminalView {
        var view = self
        view.strings = strings
        return view
    }

    func themed(_ palette: TerminalPalette) -> EmbeddedSSHTerminalView {
        var view = self
        view.palette = palette
        return view
    }
}
