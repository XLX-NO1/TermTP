import SwiftUI

struct ConnectionFormView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        let port = UInt16(state.draftPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let host = state.draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = state.draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = state.draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.draftPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        return port.map { $0 > 0 } ?? false
            && !host.isEmpty
            && !username.isEmpty
            && (state.draftUsesKey || !password.isEmpty)
            && (!state.draftUsesKey || !privateKeyPath.isEmpty)
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

                Toggle("Use private key", isOn: $state.draftUsesKey)

                if state.draftUsesKey {
                    TextField("Private key path", text: $state.draftPrivateKeyPath)
                    SecureField("Private key passphrase", text: $state.draftPrivateKeyPassphrase)
                } else {
                    SecureField("Password", text: $state.draftPassword)
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
