import SwiftUI

struct ConnectionFormView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        UInt16(state.draftPort.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
            && !state.draftHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !state.draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                Button("Save") {
                    state.saveDraftConnection()
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
