import AppKit

@MainActor
final class MenuBarController {
    static let menuBarIconSize = NSSize(width: 18, height: 18)

    private var statusItem: NSStatusItem?

    func install(state: AppState) {
        if statusItem != nil {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.makeMenuBarTemplateImage()
        item.button?.imagePosition = .imageOnly
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

    static func makeMenuBarTemplateImage() -> NSImage {
        if let image = NSImage(named: "TermCMenuBarTemplate") {
            return normalizedMenuBarTemplateImage(image)
        }

        let image = NSImage(size: menuBarIconSize)
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let topTriangle = [
            NSPoint(x: 9, y: 15),
            NSPoint(x: 3.8, y: 6),
            NSPoint(x: 14.2, y: 6)
        ]
        let bottomTriangle = [
            NSPoint(x: 9, y: 3),
            NSPoint(x: 3.8, y: 12),
            NSPoint(x: 14.2, y: 12)
        ]

        for triangle in [topTriangle, bottomTriangle] {
            path.move(to: triangle[0])
            path.line(to: triangle[1])
            path.line(to: triangle[2])
            path.close()
        }

        path.stroke()
        return normalizedMenuBarTemplateImage(image)
    }

    static func normalizedMenuBarTemplateImage(_ image: NSImage) -> NSImage {
        image.size = menuBarIconSize
        image.isTemplate = true
        return image
    }
}
