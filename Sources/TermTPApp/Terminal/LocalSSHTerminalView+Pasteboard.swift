import AppKit
import SwiftTerm

extension LocalSSHTerminalView {
    nonisolated static func needsMultilinePasteConfirmation(_ text: String) -> Bool {
        let normalizedLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)

        return normalizedLines.count > 1
    }

    func terminalContextMenu(for terminalView: LocalProcessTerminalView, strings: AppStrings) -> NSMenu {
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
}

final class ProtectedLocalProcessTerminalView: LocalProcessTerminalView {
    var strings = AppStrings(language: .zhHans)

    override func paste(_ sender: Any) {
        let clipboard = NSPasteboard.general
        let text = clipboard.string(forType: .string) ?? ""
        guard LocalSSHTerminalView.needsMultilinePasteConfirmation(text) else {
            super.paste(sender)
            return
        }

        let alert = NSAlert()
        alert.messageText = strings.confirmMultilinePasteTitle
        alert.informativeText = strings.confirmMultilinePasteMessage
        alert.addButton(withTitle: strings.paste)
        alert.addButton(withTitle: strings.cancel)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        super.paste(sender)
    }
}
