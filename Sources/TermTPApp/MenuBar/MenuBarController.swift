import AppKit

@MainActor
final class MenuBarController: NSObject {
    static let menuBarIconSize = NSSize(width: 18, height: 18)

    private var statusItem: NSStatusItem?
    private var state: AppState?
    private var windowController: TermTPWindowController?

    func install(state: AppState, windowController: TermTPWindowController) {
        self.state = state
        self.windowController = windowController
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.makeMenuBarTemplateImage()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "TermTP"
        item.menu = makeMenu(strings: state.t)
        statusItem = item
    }

    func refreshMenu() {
        guard let state, let statusItem else {
            return
        }

        statusItem.menu = makeMenu(strings: state.t)
    }

    private func makeMenu(strings: AppStrings) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: strings.showTermTP, action: #selector(showTermTP(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: strings.newConnection, action: #selector(newConnection(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: strings.quitTermTP, action: #selector(quitTermTP(_:)), keyEquivalent: "q"))

        for menuItem in menu.items {
            menuItem.target = self
        }

        return menu
    }

    @objc func showTermTP(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.windowController?.showWindow()
        }
    }

    @objc func newConnection(_ sender: NSMenuItem) {
        guard state != nil else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.windowController?.showNewConnection()
        }
    }

    @objc func quitTermTP(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    static func makeMenuBarTemplateImage() -> NSImage {
        if let image = NSImage(named: "TermTPMenuBarTemplate") {
            return normalizedMenuBarTemplateImage(image)
        }

        return makeFallbackMenuBarTemplateImage()
    }

    static func makeFallbackMenuBarTemplateImage() -> NSImage {
        let image = NSImage(size: menuBarIconSize)
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.move(to: NSPoint(x: 3.5, y: 12.5))
        path.line(to: NSPoint(x: 7.8, y: 9))
        path.line(to: NSPoint(x: 3.5, y: 5.5))
        path.move(to: NSPoint(x: 10, y: 5.5))
        path.line(to: NSPoint(x: 14.5, y: 5.5))

        path.stroke()
        return normalizedMenuBarTemplateImage(image)
    }

    static func normalizedMenuBarTemplateImage(_ image: NSImage) -> NSImage {
        image.size = menuBarIconSize
        image.isTemplate = true
        return image
    }
}
