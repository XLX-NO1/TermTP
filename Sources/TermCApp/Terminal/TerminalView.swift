import AppKit
import SwiftTerm
import SwiftUI

struct TerminalView: NSViewRepresentable {
    var transcript: String
    var onInput: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput)
    }

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let terminalView = SwiftTerm.TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        configure(terminalView)
        context.coordinator.updateTranscript(transcript, in: terminalView, configure: configure)
        return terminalView
    }

    func updateNSView(_ terminalView: SwiftTerm.TerminalView, context: Context) {
        configure(terminalView)
        context.coordinator.onInput = onInput
        context.coordinator.updateTranscript(transcript, in: terminalView, configure: configure)
    }

    private func configure(_ terminalView: SwiftTerm.TerminalView) {
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
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor TerminalViewDelegate {
        var onInput: (String) -> Void
        private var currentTranscript = ""
        private var renderedTranscript: String?
        private var renderedColumns: Int?
        private var configureTerminalView: (@MainActor (SwiftTerm.TerminalView) -> Void)?

        init(onInput: @escaping (String) -> Void) {
            self.onInput = onInput
        }

        @MainActor
        func updateTranscript(
            _ transcript: String,
            in terminalView: SwiftTerm.TerminalView,
            configure: @escaping @MainActor (SwiftTerm.TerminalView) -> Void
        ) {
            currentTranscript = transcript
            configureTerminalView = configure
            render(in: terminalView, force: renderedTranscript != transcript || renderedColumns == nil)
        }

        @MainActor
        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            guard renderedColumns != newCols else { return }
            render(in: source, force: true)
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            guard let input = String(bytes: data, encoding: .utf8) else {
                return
            }
            onInput(input)
        }
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

        @MainActor
        private func render(in terminalView: SwiftTerm.TerminalView, force: Bool = false) {
            let columns = terminalView.getTerminal().cols
            guard force || renderedColumns != columns else { return }

            renderedColumns = columns
            renderedTranscript = currentTranscript
            terminalView.getTerminal().resetToInitialState()
            configureTerminalView?(terminalView)
            terminalView.feed(text: "\u{1b}[2J\u{1b}[3J\u{1b}[H")
            terminalView.feed(text: currentTranscript.normalizedTerminalLineEndings)
        }
    }
}

private extension String {
    var normalizedTerminalLineEndings: String {
        var output = ""
        output.reserveCapacity(count)

        var previousWasCarriageReturn = false
        for character in self {
            if character == "\n", !previousWasCarriageReturn {
                output.append("\r")
            }

            output.append(character)
            previousWasCarriageReturn = character == "\r"
        }

        return output
    }
}
