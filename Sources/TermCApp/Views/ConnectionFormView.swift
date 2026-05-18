import SwiftUI
import TermCCore

struct ConnectionFormView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        let port = UInt16(state.draftPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let host = state.draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = state.draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = state.draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.draftPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepAliveInterval = Int(state.draftKeepAliveInterval.trimmingCharacters(in: .whitespacesAndNewlines))
        let keepAliveMaxCount = Int(state.draftKeepAliveMaxCount.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardLocalPort = UInt16(state.draftForwardLocalPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationHost = state.draftForwardDestinationHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let forwardDestinationPort = UInt16(state.draftForwardDestinationPort.trimmingCharacters(in: .whitespacesAndNewlines))

        return port.map { $0 > 0 } ?? false
            && !host.isEmpty
            && !username.isEmpty
            && (state.draftUsesKey || !password.isEmpty)
            && (!state.draftUsesKey || !privateKeyPath.isEmpty)
            && (!state.draftKeepAliveEnabled || ((keepAliveInterval ?? 0) > 0 && (keepAliveMaxCount ?? 0) > 0))
            && (!state.draftForwardEnabled || forwardLocalPort != nil)
            && (!state.draftForwardEnabled || state.draftForwardDirection == .dynamic || (!forwardDestinationHost.isEmpty && forwardDestinationPort != nil))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Connection")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Alias", text: $state.draftAlias)
                TextField("Host", text: $state.draftHost)
                TextField("Port", text: $state.draftPort)
                TextField("Username", text: $state.draftUsername)
                TextField("Tags", text: $state.draftTags)

                Toggle("Use private key", isOn: $state.draftUsesKey)

                if state.draftUsesKey {
                    TextField("Private key path", text: $state.draftPrivateKeyPath)
                    SecureField("Private key passphrase", text: $state.draftPrivateKeyPassphrase)
                } else {
                    SecureField("Password", text: $state.draftPassword)
                }

                Section("Connection") {
                    Toggle("Keep connection alive", isOn: $state.draftKeepAliveEnabled)

                    if state.draftKeepAliveEnabled {
                        TextField("Alive interval seconds", text: $state.draftKeepAliveInterval)
                        TextField("Alive max count", text: $state.draftKeepAliveMaxCount)
                    }

                    TextField("Jump host", text: $state.draftJumpHost)
                }

                Section("Port Forwarding") {
                    Toggle("Enable forwarding", isOn: $state.draftForwardEnabled)

                    if state.draftForwardEnabled {
                        Picker("Type", selection: $state.draftForwardDirection) {
                            Text("Local").tag(ConnectionRecord.PortForward.Direction.local)
                            Text("Remote").tag(ConnectionRecord.PortForward.Direction.remote)
                            Text("Dynamic").tag(ConnectionRecord.PortForward.Direction.dynamic)
                        }
                        TextField("Bind address", text: $state.draftForwardBindAddress)
                        TextField("Port", text: $state.draftForwardLocalPort)

                        if state.draftForwardDirection != .dynamic {
                            TextField("Destination host", text: $state.draftForwardDestinationHost)
                            TextField("Destination port", text: $state.draftForwardDestinationPort)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    state.isConnectionFormPresented = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Connect") {
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
}

#Preview {
    ConnectionFormView(state: AppState())
}
