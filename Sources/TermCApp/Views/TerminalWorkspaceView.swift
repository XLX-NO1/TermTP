import SwiftUI
import TermCCore

struct TerminalWorkspaceView: View {
    let tabs: [TerminalTab]
    @Binding var selectedTabID: TerminalTab.ID?

    private var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID } ?? tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip

            TerminalView(transcript: selectedTab?.transcript ?? "")
        }
        .background(Color.black)
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
