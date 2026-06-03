import Foundation
import TermTPCore

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

    func attachLocalSSHProcess(
        to id: TerminalTab.ID,
        connection: ConnectionRecord,
        credential: Credential?,
        runID: UUID? = nil,
        backend: TerminalSSHProcessBackend = .automatic
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        tabs[index].localProcess = .ssh(
            connection,
            credential: credential,
            runID: runID ?? UUID(),
            backend: backend
        )
    }

    func handleLocalSSHProcessStarted(_ started: LocalSSHProcessStarted) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            markLocalSSHProcessRunningIfStillActive(started)
        }
    }

    private func markLocalSSHProcessRunningIfStillActive(_ started: LocalSSHProcessStarted) {
        guard let index = tabs.firstIndex(where: { $0.id == started.tabID }) else {
            return
        }

        guard case .ssh(let connection, _, let runID, _) = tabs[index].localProcess,
              connection.id == started.connection.id,
              runID == started.runID
        else {
            return
        }

        guard tabs[index].state == .connecting else {
            return
        }

        tabs[index].state = .localProcessRunning
    }

    func handleLocalSSHProcessExit(_ exit: LocalSSHProcessExit) {
        guard let index = tabs.firstIndex(where: { $0.id == exit.tabID }) else {
            return
        }

        let normalizedExitCode = exit.normalizedExitCode
        let localSSHDebugLogWriter = localSSHDebugLogWriter
        Task.detached(priority: .utility) {
            localSSHDebugLogWriter(exit)
        }

        guard case .ssh(let connection, let credential, let runID, let backend) = tabs[index].localProcess,
              connection.id == exit.connection.id,
              runID == exit.runID
        else {
            return
        }

        if backend == .automatic,
           exit.launch.executable == "embedded-citadel",
           normalizedExitCode != 0 {
            tabs[index].localProcess = .ssh(
                connection,
                credential: credential,
                runID: UUID(),
                backend: .openSSHOnly
            )
            tabs[index].state = .connecting
            tabs[index].transcript += "\nTermTP embedded SSH failed; falling back to isolated OpenSSH.\n"
            return
        }

        let exitDescription = normalizedExitCode.map { "ssh exited with code \($0)" } ?? "ssh exited"
        tabs[index].localProcess = nil
        tabs[index].state = normalizedExitCode == 0 ? .disconnected : .failed(exitDescription)
        if normalizedExitCode == 0 {
            tabs[index].transcript += "\n\(exitDescription)\n"
        } else {
            let message = t.failedToConnect + " \(exit.connection.username)@\(exit.connection.host):\(exit.connection.port)"
            tabs[index].transcript += "\n\(message)\n\(exitDescription)\n"
        }
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
