import SwiftUI

@main
struct TermTPApp: App {
    @NSApplicationDelegateAdaptor(TermTPAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(state: appDelegate.state)
        }
        .commands {
            CommandMenu(appDelegate.state.t.view) {
                Button(appDelegate.state.t.toggleConnections) {
                    appDelegate.state.toggleSidebar()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(appDelegate.state.t.toggleSFTPDrawer) {
                    appDelegate.state.toggleSFTPDrawer()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}
