import TermCCore

extension AppState {
    func closeTab(_ id: TerminalTab.ID) async {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        let closedTab = tabs[index]
        tabs.remove(at: index)
        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
            remotePath = tabs[nextIndex].remotePath
            await refreshRemoteFiles()
        }

        try? await closedTab.session?.disconnect()
    }

    func selectTab(_ id: TerminalTab.ID) async {
        guard let tab = tabs.first(where: { $0.id == id }) else {
            return
        }

        selectedTabID = id
        remotePath = tab.remotePath
        await refreshRemoteFiles()
    }

    func sendInputToSelectedTab(_ input: String) {
        guard let selectedTabID else {
            return
        }

        pendingTerminalCommands[selectedTabID] = TerminalCommand(text: input)
        appendTranscript(input, to: selectedTabID)
    }

    func clearPendingTerminalCommand(for id: TerminalTab.ID, commandID: TerminalCommand.ID) {
        guard pendingTerminalCommands[id]?.id == commandID else {
            return
        }

        pendingTerminalCommands[id] = nil
    }

    func renameTab(_ id: TerminalTab.ID, to title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedTitle.isEmpty,
            let index = tabs.firstIndex(where: { $0.id == id })
        else {
            return
        }

        tabs[index].title = trimmedTitle
    }

    func updateTab(id: TerminalTab.ID, state: SSHSessionState, transcript: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].state = state
        tabs[index].transcript = transcript
    }

    func appendTranscript(_ transcript: String, to id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].transcript += transcript
    }

    func attachLocalSSHProcess(to id: TerminalTab.ID, connection: ConnectionRecord, credential: Credential?) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].localProcess = .ssh(connection, credential: credential)
    }

    var selectedSession: SSHSessionProviding? {
        guard
            let selectedTabID,
            let tab = tabs.first(where: { $0.id == selectedTabID })
        else {
            return nil
        }

        return tab.session
    }

    func attachSession(_ session: SSHSessionProviding, to id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].session = session
    }
}
