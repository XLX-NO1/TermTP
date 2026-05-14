import SwiftUI
import TermCCore

struct TerminalWorkspaceView: View {
    let tabs: [TerminalTab]
    @Binding var selectedTabID: TerminalTab.ID?
    var onCloseTab: (TerminalTab.ID) -> Void = { _ in }
    var onTerminalInput: (String) -> Void = { _ in }

    private var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID } ?? tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip

            terminalStack
        }
        .background(Color.black)
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
            LocalSSHTerminalView(connection: connection, credential: credential)
        } else {
            TerminalView(
                transcript: tab.transcript,
                onInput: onTerminalInput
            )
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 5) {
            ForEach(tabs) { tab in
                Button {
                    selectedTabID = tab.id
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
                    Button("Close") {
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
