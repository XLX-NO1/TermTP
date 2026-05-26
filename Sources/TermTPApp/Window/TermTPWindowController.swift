import AppKit
import SwiftUI

@MainActor
final class TermTPWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func showWindow() {
        let window = makeWindowIfNeeded()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.setIsVisible(true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func showNewConnection() {
        showWindow()
        state.beginNewConnection()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.miniaturize(nil)
        return false
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let rootView = RootView(state: state)
            .frame(
                minWidth: AppLayout.minimumWindowWidth,
                minHeight: AppLayout.minimumWindowHeight
            )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TermTP"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(.init(
            width: AppLayout.defaultWindowWidth,
            height: AppLayout.defaultWindowHeight
        ))
        window.minSize = .init(
            width: AppLayout.minimumWindowWidth,
            height: AppLayout.minimumWindowHeight
        )
        window.center()
        self.window = window
        return window
    }
}
