import SwiftUI

@main
struct TermCApp: App {
    @NSApplicationDelegateAdaptor(TermTPAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("View") {
                Button("Toggle Connections") {
                    appDelegate.state.toggleSidebar()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button("Toggle SFTP Drawer") {
                    appDelegate.state.toggleSFTPDrawer()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}
