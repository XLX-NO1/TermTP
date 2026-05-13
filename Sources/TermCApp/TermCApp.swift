import SwiftUI

@main
struct TermCApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup("TermC") {
            RootView(state: state)
                .frame(minWidth: 1040, minHeight: 680)
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
