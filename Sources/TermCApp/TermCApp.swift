import SwiftUI

@main
struct TermCApp: App {
    @State private var state = AppState()
    @State private var menuBarController = MenuBarController()

    var body: some Scene {
        WindowGroup("TermTP") {
            RootView(state: state)
                .frame(minWidth: 1040, minHeight: 680)
                .task {
                    menuBarController.install(state: state)
                }
        }
        .commands {
            CommandMenu("View") {
                Button("Toggle Connections") {
                    state.toggleSidebar()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button("Toggle SFTP Drawer") {
                    state.toggleSFTPDrawer()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}
