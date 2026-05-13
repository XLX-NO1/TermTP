import AppKit

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?

    func install(state: AppState) {
        if statusItem != nil {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(named: "TermCMenuBarTemplate")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "TermC"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Show TermC",
                action: #selector(showTermC),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "New Connection",
                action: #selector(newConnection(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit TermC",
                action: #selector(quitTermC),
                keyEquivalent: "q"
            )
        )

        for menuItem in menu.items {
            menuItem.target = self
        }

        menu.item(withTitle: "New Connection")?.representedObject = state
        item.menu = menu
        statusItem = item
    }

    @objc private func showTermC() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func newConnection(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? AppState else {
            return
        }

        showTermC()
        state.beginNewConnection()
    }

    @objc private func quitTermC() {
        NSApp.terminate(nil)
    }
}
