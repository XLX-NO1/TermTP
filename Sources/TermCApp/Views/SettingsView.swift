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
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
        .navigationTitle(state.t.settings)
    }
}

#Preview {
    SettingsView(state: AppState())
}
