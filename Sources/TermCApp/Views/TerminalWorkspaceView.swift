import SwiftUI
import TermCCore

struct TerminalWorkspaceView: View {
    let tabs: [TerminalTab]
    @Binding var selectedTabID: TerminalTab.ID?
    var terminalFontSize = 11
    var terminalPalette = TerminalPalette.palette(for: .classicGreen)
    var pendingCommands: [TerminalTab.ID: TerminalCommand] = [:]
    var onSelectTab: (TerminalTab.ID) -> Void = { _ in }
    var onCloseTab: (TerminalTab.ID) -> Void = { _ in }
    var onRenameTab: (TerminalTab.ID, String) -> Void = { _, _ in }
    var onCommandHandled: (TerminalTab.ID, TerminalCommand.ID) -> Void = { _, _ in }
    var onTerminalInput: (String) -> Void = { _ in }
    var strings = AppStrings(language: .zhHans)
    @State private var tabRenameTarget: TabRenameTarget?
    @State private var tabRenameTitle = ""

    private struct TabRenameTarget: Identifiable {
        var id: TerminalTab.ID
        var title: String
    }

    private var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID } ?? tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip

            terminalStack
        }
        .background(Color.black)
        .sheet(item: $tabRenameTarget) { tab in
            VStack(alignment: .leading, spacing: 14) {
                Text(strings.renameTab)
                    .font(.headline)

                TextField(strings.title, text: $tabRenameTitle)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    Button(strings.cancel, role: .cancel) {
                        tabRenameTarget = nil
                    }

                    Button(strings.ok) {
                        onRenameTab(tab.id, tabRenameTitle)
                        tabRenameTarget = nil
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tabRenameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 300)
        }
    }

    private var terminalStack: some View {
        ZStack {
            ForEach(tabs) { tab in
                terminalContent(for: tab)
                    .opacity(tab.id == selectedTab?.id ? 1 : 0)
                    .allowsHitTesting(tab.id == selectedTab?.id)
                    .accessibilityHidden(tab.id != selectedTab?.id)
            }
        }
    }

    @ViewBuilder
    private func terminalContent(for tab: TerminalTab) -> some View {
        if case .ssh(let connection, let credential) = tab.localProcess {
            LocalSSHTerminalView(connection: connection, credential: credential, fontSize: terminalFontSize)
                .themed(terminalPalette)
                .localized(strings)
                .pendingCommand(pendingCommands[tab.id]) { commandID in
                    onCommandHandled(tab.id, commandID)
                }
        } else {
            TerminalView(
                transcript: tab.transcript,
                fontSize: terminalFontSize,
                palette: terminalPalette,
                onInput: onTerminalInput
            )
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 5) {
            ForEach(tabs) { tab in
                Button {
                    onSelectTab(tab.id)
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(color(for: tab.state))
                            .frame(width: 6, height: 6)

                        Text(tab.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(tab.id == selectedTabID ? .white : .secondary)
                    .background(
                        tab.id == selectedTabID ? Color.white.opacity(0.14) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(strings.rename) {
                        tabRenameTitle = tab.title
                        tabRenameTarget = TabRenameTarget(id: tab.id, title: tab.title)
                    }

                    Button(strings.close) {
                        onCloseTab(tab.id)
                    }
                    .disabled(tabs.count <= 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(red: 0.10, green: 0.11, blue: 0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func color(for state: SSHSessionState) -> Color {
        switch state {
        case .connecting:
            return .yellow
        case .connected:
            return .green
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
}

#Preview {
    @Previewable @State var selectedTabID: TerminalTab.ID? = TerminalTab.welcome.id

    TerminalWorkspaceView(tabs: [.welcome], selectedTabID: $selectedTabID)
        .frame(width: 640, height: 480)
}
