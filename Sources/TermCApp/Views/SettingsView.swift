import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Picker(state.t.language, selection: $state.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .onChange(of: state.language) { _, _ in
                (NSApp.delegate as? TermTPAppDelegate)?.refreshMenuBar()
            }

            Picker(state.t.terminalTheme, selection: $state.terminalTheme) {
                ForEach(TerminalTheme.allCases) { theme in
                    Text(state.t.terminalThemeName(theme)).tag(theme)
                }
            }

            Section(state.t.security) {
                if state.trustedHostKeys.isEmpty {
                    Text(state.t.noTrustedHostKeys)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.trustedHostKeys) { item in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.hostPort)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(item.key)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                state.removeTrustedHostKey(hostPort: item.hostPort)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button(role: .destructive) {
                        state.clearTrustedHostKeys()
                    } label: {
                        Text(state.t.clearTrustedHostKeys)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .navigationTitle(state.t.settings)
    }
}

#Preview {
    SettingsView(state: AppState())
}
