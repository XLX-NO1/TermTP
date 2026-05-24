import SwiftUI
import TermCCore

struct SFTPCredentialPromptView: View {
    @Bindable var state: AppState
    let prompt: SFTPCredentialPrompt
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(state.t.sftpPasswordTitle)
                .font(.headline)

            Text("\(prompt.connection.username)@\(prompt.connection.host):\(prompt.connection.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(state.t.sftpPasswordMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(state.t.password, text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button(state.t.cancel, role: .cancel) {
                    state.cancelSFTPCredentialPrompt()
                }

                Button(state.t.ok) {
                    Task {
                        await state.submitSFTPCredential(password: password)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

#Preview {
    SFTPCredentialPromptView(
        state: AppState(),
        prompt: SFTPCredentialPrompt(
            tabID: UUID(),
            connection: .samplePassword,
            path: "."
        )
    )
}
