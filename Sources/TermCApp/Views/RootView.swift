import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            compactControls

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TerminalWorkspaceView(tabs: state.tabs, selectedTabID: $state.selectedTabID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if state.isSFTPDrawerVisible {
                        SFTPDrawerView(state: state)
                            .frame(height: AppLayout.transferDrawerHeight)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if state.isSidebarVisible {
                    ConnectionSidebarView(state: state)
                        .frame(width: AppLayout.connectionSidebarWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.09, blue: 0.10))
        .sheet(isPresented: $state.isConnectionFormPresented) {
            ConnectionFormView(state: state)
        }
        .animation(.snappy(duration: 0.22), value: state.isSidebarVisible)
        .animation(.snappy(duration: 0.22), value: state.isSFTPDrawerVisible)
    }

    private var compactControls: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 76)

            Button {
                state.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .help("Toggle Connections")

            Button {
                state.toggleSFTPDrawer()
            } label: {
                Image(systemName: "rectangle.bottomthird.inset.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .help("Toggle SFTP Drawer")

            Spacer(minLength: 0)
        }
        .frame(height: 22)
        .background(Color(red: 0.09, green: 0.10, blue: 0.11))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

#Preview {
    RootView(state: AppState())
        .frame(width: 720, height: 460)
}
