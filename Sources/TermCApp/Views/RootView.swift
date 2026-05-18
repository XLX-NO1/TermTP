import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            compactControls

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TerminalWorkspaceView(
                        tabs: state.tabs,
                        selectedTabID: $state.selectedTabID,
                        terminalFontSize: state.terminalFontSize,
                        pendingCommands: state.pendingTerminalCommands,
                        onSelectTab: { tabID in
                            Task {
                                await state.selectTab(tabID)
                            }
                        },
                        onCloseTab: { tabID in
                            Task {
                                await state.closeTab(tabID)
                            }
                        },
                        onRenameTab: state.renameTab,
                        onCommandHandled: state.clearPendingTerminalCommand,
                        onTerminalInput: state.sendInputToSelectedTab
                    )
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
        .alert(
            "Trust SSH Host Key?",
            isPresented: Binding(
                get: { state.pendingHostKeyPrompt != nil },
                set: { isPresented in
                    if !isPresented {
                        state.rejectPendingHostKey()
                    }
                }
            ),
            presenting: state.pendingHostKeyPrompt
        ) { _ in
            Button("Reject", role: .cancel) {
                state.rejectPendingHostKey()
            }
            Button("Trust") {
                state.trustPendingHostKey()
            }
        } message: { prompt in
            Text("""
            \(prompt.host):\(prompt.port)
            \(prompt.fingerprint)
            """)
        }
        .animation(.snappy(duration: 0.22), value: state.isSidebarVisible)
        .animation(.snappy(duration: 0.22), value: state.isSFTPDrawerVisible)
    }

    private var compactControls: some View {
        HStack(spacing: 6) {
            Button {
                state.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.isSidebarVisible ? .white : .white.opacity(0.54))
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .help("Toggle Connections")

            Button {
                state.toggleSFTPDrawer()
            } label: {
                Image(systemName: "rectangle.bottomthird.inset.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.isSFTPDrawerVisible ? .white : .white.opacity(0.54))
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .help("Toggle SFTP Drawer")

            Menu {
                Button("List files") {
                    state.sendInputToSelectedTab("ls -la\n")
                }
                Button("Disk usage") {
                    state.sendInputToSelectedTab("df -h\n")
                }
                Button("Memory usage") {
                    state.sendInputToSelectedTab("free -h\n")
                }
                Button("Process monitor") {
                    state.sendInputToSelectedTab("top\n")
                }
                Divider()
                Button("Server status") {
                    state.sendInputToSelectedTab("printf '\\n== System ==\\n'; uname -a; printf '\\n== Uptime ==\\n'; uptime; printf '\\n== Disk ==\\n'; df -h; printf '\\n== Memory ==\\n'; free -h 2>/dev/null || vm_stat\\n")
                }
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
            }
            .menuStyle(.borderlessButton)
            .foregroundStyle(.white.opacity(0.86))
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .help("Command Snippets")

            Button {
                state.decreaseTerminalFontSize()
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .help("Smaller Font")

            Button {
                state.increaseTerminalFontSize()
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .help("Larger Font")

            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.vertical, 4)
        .frame(height: 30)
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
