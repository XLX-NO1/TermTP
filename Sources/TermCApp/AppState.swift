import Foundation
import Observation
import TermCCore

@Observable
final class AppState {
    var isSidebarVisible = true
    var isSFTPDrawerVisible = true
    var selectedTabID: TerminalTab.ID?
    var tabs: [TerminalTab]
    var connections: [ConnectionRecord]
    var transfers: [TransferRecord]

    init(
        tabs: [TerminalTab] = [.welcome],
        connections: [ConnectionRecord] = [.samplePassword],
        transfers: [TransferRecord] = []
    ) {
        self.tabs = tabs
        self.connections = connections
        self.transfers = transfers
        self.selectedTabID = tabs.first?.id
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleSFTPDrawer() {
        isSFTPDrawerVisible.toggle()
    }
}

struct TerminalTab: Identifiable, Equatable {
    var id: UUID
    var title: String
    var state: SSHSessionState
    var transcript: String

    init(
        id: UUID = UUID(),
        title: String,
        state: SSHSessionState,
        transcript: String
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.transcript = transcript
    }
}

extension TerminalTab {
    static let welcome = TerminalTab(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Welcome",
        state: .disconnected,
        transcript: """
        Welcome to TermC

        Select a connection from the sidebar to start an SSH session.
        """
    )
}
