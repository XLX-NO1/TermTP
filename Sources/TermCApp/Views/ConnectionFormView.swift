import SwiftUI
import TermCCore
import UniformTypeIdentifiers

struct ConnectionFormView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        let port = UInt16(state.draftPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let host = state.draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = state.draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = state.draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepAliveInterval = Int(state.draftKeepAliveInterval.trimmingCharacters(in: .whitespacesAndNewlines))
        let keepAliveMaxCount = Int(state.draftKeepAliveMaxCount.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardLocalPort = UInt16(state.draftForwardLocalPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationHost = state.draftForwardDestinationHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let forwardDestinationPort = UInt16(state.draftForwardDestinationPort.trimmingCharacters(in: .whitespacesAndNewlines))

        return port.map { $0 > 0 } ?? false
            && !host.isEmpty
            && !username.isEmpty
            && (!state.draftUsesKey || !privateKeyPath.isEmpty)
            && (!state.draftKeepAliveEnabled || ((keepAliveInterval ?? 0) > 0 && (keepAliveMaxCount ?? 0) > 0))
            && (!state.draftForwardEnabled || forwardLocalPort != nil)
            && (!state.draftForwardEnabled || state.draftForwardDirection == .dynamic || (!forwardDestinationHost.isEmpty && forwardDestinationPort != nil))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(state.t.newConnection)
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField(state.t.alias, text: $state.draftAlias)
                TextField(state.t.group, text: $state.draftGroup)
                TextField(state.t.host, text: $state.draftHost)
                TextField(state.t.port, text: $state.draftPort)
                TextField(state.t.username, text: $state.draftUsername)
                TextField(state.t.tags, text: $state.draftTags)

                Toggle(state.t.usePrivateKey, isOn: $state.draftUsesKey)

                if state.draftUsesKey {
                    HStack(spacing: 8) {
                        TextField(state.t.privateKeyPath, text: $state.draftPrivateKeyPath)

                        Button {
                            choosePrivateKey()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help(state.t.choosePrivateKey)
                    }
                    SecureField(state.t.privateKeyPassphrase, text: $state.draftPrivateKeyPassphrase)
                } else {
                    SecureField(state.t.password, text: $state.draftPassword)
                }

                Section(state.t.connection) {
                    Toggle(state.t.keepConnectionAlive, isOn: $state.draftKeepAliveEnabled)

                    if state.draftKeepAliveEnabled {
                        TextField(state.t.aliveIntervalSeconds, text: $state.draftKeepAliveInterval)
                        TextField(state.t.aliveMaxCount, text: $state.draftKeepAliveMaxCount)
                    }

                    TextField(state.t.jumpHost, text: $state.draftJumpHost)
                    TextField(state.t.defaultRemotePath, text: $state.draftDefaultRemotePath)
                }

                Section(state.t.portForwarding) {
                    Toggle(state.t.enableForwarding, isOn: $state.draftForwardEnabled)

                    if state.draftForwardEnabled {
                        Picker(state.t.type, selection: $state.draftForwardDirection) {
                            Text(state.t.local).tag(ConnectionRecord.PortForward.Direction.local)
                            Text(state.t.remote).tag(ConnectionRecord.PortForward.Direction.remote)
                            Text(state.t.dynamic).tag(ConnectionRecord.PortForward.Direction.dynamic)
                        }
                        TextField(state.t.bindAddress, text: $state.draftForwardBindAddress)
                        TextField(state.t.port, text: $state.draftForwardLocalPort)

                        if state.draftForwardDirection != .dynamic {
                            TextField(state.t.destinationHost, text: $state.draftForwardDestinationHost)
                            TextField(state.t.destinationPort, text: $state.draftForwardDestinationPort)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button(state.t.cancel, role: .cancel) {
                    state.isConnectionFormPresented = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(state.t.connect) {
                    Task {
                        await state.connectDraftConnection()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func choosePrivateKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        state.draftPrivateKeyPath = url.path
    }
}

#Preview {
    ConnectionFormView(state: AppState())
}
