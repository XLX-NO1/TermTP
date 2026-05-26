import SwiftUI

struct RootView: View {
    @Bindable var state: AppState
    @State private var isCommandMenuPresented = false
    @State private var isFontSizeMenuPresented = false

    var body: some View {
        VStack(spacing: 0) {
            compactControls

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TerminalWorkspaceView(
                        tabs: state.tabs,
                        selectedTabID: $state.selectedTabID,
                        terminalFontSize: state.terminalFontSize,
                        terminalPalette: state.terminalPalette,
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
                        onTerminalInput: state.sendInputToSelectedTab,
                        strings: state.t
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
        .overlay(alignment: .topTrailing) {
            if let notification = state.notification {
                NotificationBanner(notification: notification) {
                    state.dismissNotification()
                }
                .padding(.top, 36)
                .padding(.trailing, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $state.isConnectionFormPresented) {
            ConnectionFormView(state: state)
        }
        .sheet(isPresented: $state.isSettingsPresented) {
            SettingsView(state: state)
        }
        .sheet(item: $state.pendingSFTPCredentialPrompt) { prompt in
            SFTPCredentialPromptView(state: state, prompt: prompt)
        }
        .alert(
            state.t.trustHostKeyTitle,
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
            Button(state.t.reject, role: .cancel) {
                state.rejectPendingHostKey()
            }
            Button(state.t.trust) {
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
            .help(state.t.toggleConnections)

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
            .help(state.t.toggleSFTPDrawer)

            Button {
                isCommandMenuPresented.toggle()
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help(state.t.commandSnippets)
            .popover(isPresented: $isCommandMenuPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    commandMenuButton(title: state.t.listFiles, command: "ls -la\n")
                    commandMenuButton(title: state.t.diskUsage, command: "df -h\n")
                    commandMenuButton(title: state.t.memoryUsage, command: "free -h\n")
                    commandMenuButton(title: state.t.processMonitor, command: "top\n")

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.vertical, 3)

                    commandMenuButton(
                        title: state.t.serverStatus,
                        command: "printf '\\n== System ==\\n'; uname -a; printf '\\n== Uptime ==\\n'; uptime; printf '\\n== Disk ==\\n'; df -h; printf '\\n== Memory ==\\n'; free -h 2>/dev/null || vm_stat\\n"
                    )
                }
                .padding(6)
                .background(Color(red: 0.09, green: 0.10, blue: 0.11))
            }

            Button {
                isFontSizeMenuPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text("\(state.terminalFontSize)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 18, alignment: .trailing)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(width: 42, height: 22)
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help(state.t.fontSize)
            .popover(isPresented: $isFontSizeMenuPresented, arrowEdge: .bottom) {
                VStack(spacing: 2) {
                    ForEach(state.terminalFontSizeOptions, id: \.self) { size in
                        Button {
                            state.terminalFontSize = size
                            isFontSizeMenuPresented = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: state.terminalFontSize == size ? "checkmark" : "")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 12)

                                Text("\(size)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(width: 22, alignment: .leading)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 24, alignment: .leading)
                            .padding(.horizontal, 8)
                            .background(
                                state.terminalFontSize == size ? Color.white.opacity(0.14) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(red: 0.09, green: 0.10, blue: 0.11))
            }

            Spacer(minLength: 0)

            Button {
                state.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 22)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help(state.t.settings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 30)
        .background(Color(red: 0.09, green: 0.10, blue: 0.11))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func commandMenuButton(title: String, command: String) -> some View {
        Button {
            state.sendInputToSelectedTab(command)
            isCommandMenuPresented = false
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 108, height: 24, alignment: .leading)
                .padding(.horizontal, 8)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationBanner: View {
    let notification: AppNotification
    let onDismiss: () -> Void

    private var color: Color {
        switch notification.kind {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(notification.message)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
    }
}

#Preview {
    RootView(state: AppState())
        .frame(width: 720, height: 460)
}
