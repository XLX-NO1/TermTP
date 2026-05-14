import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            if state.isSidebarVisible {
                ConnectionSidebarView(state: state)
                    .frame(width: 260)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            TerminalWorkspaceView(tabs: state.tabs, selectedTabID: $state.selectedTabID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.isSFTPDrawerVisible {
                SFTPDrawerView(state: state)
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.09, blue: 0.10))
        .sheet(isPresented: $state.isConnectionFormPresented) {
            ConnectionFormView(state: state)
        }
        .animation(.snappy(duration: 0.22), value: state.isSidebarVisible)
        .animation(.snappy(duration: 0.22), value: state.isSFTPDrawerVisible)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    state.toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Connections")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.toggleSFTPDrawer()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Toggle SFTP Drawer")
            }
        }
    }
}

#Preview {
    RootView(state: AppState())
        .frame(width: 1180, height: 720)
}
