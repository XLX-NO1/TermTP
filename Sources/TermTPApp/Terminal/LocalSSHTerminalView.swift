import AppKit
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
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment
        )
        context.coordinator.onCommandHandled = onCommandHandled
        context.coordinator.lastSentCommandID = nil
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
