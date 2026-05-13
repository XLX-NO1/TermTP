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

            ScrollView {
                Text(selectedTab?.transcript ?? "")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(red: 0.45, green: 1.0, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
                    .textSelection(.enabled)
            }
            .background(Color.black)
        }
        .background(Color.black)
    }

    private var tabStrip: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    selectedTabID = tab.id
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(color(for: tab.state))
                            .frame(width: 8, height: 8)

                        Text(tab.title)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(tab.id == selectedTabID ? .white : .secondary)
                    .background(
                        tab.id == selectedTabID ? Color.white.opacity(0.14) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
