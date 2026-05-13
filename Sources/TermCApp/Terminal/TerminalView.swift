import AppKit
import SwiftTerm
import SwiftUI

struct TerminalView: NSViewRepresentable {
    var transcript: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let terminalView = SwiftTerm.TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        configure(terminalView)
        render(transcript, in: terminalView, coordinator: context.coordinator)
        return terminalView
    }

    func updateNSView(_ terminalView: SwiftTerm.TerminalView, context: Context) {
        configure(terminalView)
        render(transcript, in: terminalView, coordinator: context.coordinator)
    }

    private func configure(_ terminalView: SwiftTerm.TerminalView) {
        terminalView.autoresizingMask = [.width, .height]
        terminalView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
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

    private func render(_ transcript: String, in terminalView: SwiftTerm.TerminalView, coordinator: Coordinator) {
        guard coordinator.renderedTranscript != transcript else { return }

        coordinator.renderedTranscript = transcript
        terminalView.feed(text: "\u{1b}[2J\u{1b}[3J\u{1b}[H")
        terminalView.feed(text: transcript.normalizedTerminalLineEndings)
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        var renderedTranscript: String?

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
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
