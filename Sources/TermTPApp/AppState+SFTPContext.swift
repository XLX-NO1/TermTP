import Foundation
import TermTPCore

extension AppState {
    var selectedSFTPContext: SFTPContext? {
        guard
            let selectedTabID
        else {
            return nil
        }

        return sftpContext(for: selectedTabID)
    }

    var selectedSFTPCredentialConnection: ConnectionRecord? {
        selectedSession?.sftpCredentialConnection
    }

    func sftpContext(for tabID: TerminalTab.ID) -> SFTPContext? {
        guard
            let tab = tabs.first(where: { $0.id == tabID }),
            let session = tab.session
        else {
            return nil
        }

        return SFTPContext(tabID: tabID, path: tab.remotePath, session: session)
    }

    func saveRemotePathForSelectedTab() {
        guard
            let selectedTabID,
            let index = tabs.firstIndex(where: { $0.id == selectedTabID })
        else {
            return
        }

        tabs[index].remotePath = remotePath
    }

    func setRemotePath(_ path: String, for tabID: TerminalTab.ID) {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextPath = normalizedPath.isEmpty ? "." : normalizedPath
        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].remotePath = nextPath
        }
        if selectedTabID == tabID {
            remotePath = nextPath
        }
    }

    func updateRemoteFiles(_ files: [RemoteFile], path: String, tabID: TerminalTab.ID) {
        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].remotePath = path
        }

        if selectedTabID == tabID {
            remotePath = path
            remoteFiles = files
        }
    }
}

struct SFTPContext {
    var tabID: TerminalTab.ID
    var path: String
    var session: SSHSessionProviding
}
