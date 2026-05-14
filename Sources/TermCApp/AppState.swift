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
    var isConnectionFormPresented = false
    var draftAlias = ""
    var draftHost = ""
    var draftPort = "22"
    var draftUsername = ""
    var draftUsesKey = false
    var draftPrivateKeyPath = ""
    var remotePath = "/var/www"
    var remoteFiles: [RemoteFile] = [
        RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
    ]

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

    func refreshRemoteFiles() {
        remoteFiles = [
            RemoteFile(name: "app.tar.gz", path: "\(remotePath)/app.tar.gz", kind: .file, size: 2048),
            RemoteFile(name: "logs", path: "\(remotePath)/logs", kind: .directory, size: 0)
        ]
    }

    func beginNewConnection() {
        draftAlias = ""
        draftHost = ""
        draftPort = "22"
        draftUsername = NSUserName()
        draftUsesKey = false
        draftPrivateKeyPath = ""
        isConnectionFormPresented = true
    }

    func saveDraftConnection() {
        let alias = draftAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let port = UInt16(draftPort.trimmingCharacters(in: .whitespacesAndNewlines)),
            port > 0,
            !host.isEmpty,
            !username.isEmpty,
            !draftUsesKey || !privateKeyPath.isEmpty
        else {
            return
        }

        let authentication: ConnectionAuthentication = draftUsesKey
            ? .publicKey(privateKeyPath: privateKeyPath)
            : .password
        let connection = ConnectionRecord(
            alias: alias.isEmpty ? host : alias,
            host: host,
            port: port,
            username: username,
            authentication: authentication
        )

        connections.append(connection)
        isConnectionFormPresented = false
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
