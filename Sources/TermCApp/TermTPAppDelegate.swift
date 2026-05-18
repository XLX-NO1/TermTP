import AppKit

@MainActor
final class TermTPAppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    private let menuBarController = MenuBarController()
    private lazy var windowController = TermTPWindowController(state: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.install(
            state: state,
            windowController: windowController
        )
        windowController.showWindow()

        Task {
            await state.loadConnections()
        }
    }

    func refreshMenuBar() {
        menuBarController.refreshMenu()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        windowController.showWindow()
        return true
    }
}
