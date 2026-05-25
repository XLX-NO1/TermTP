import Foundation
import TermCCore

extension AppState {
    func refreshRemoteFiles() async {
        saveRemotePathForSelectedTab()

        guard
            let selectedTabID,
            let session = selectedSession
        else {
            remoteFiles = []
            return
        }

        await refreshRemoteFiles(tabID: selectedTabID, path: remotePath, session: session)
    }

    func refreshRemoteFiles(
        tabID: TerminalTab.ID,
        path: String,
        session: SSHSessionProviding
    ) async {
        if session.sftpCredentialConnection != nil {
            updateRemoteFiles([], path: path, tabID: tabID)
            return
        }

        do {
            let files = try await sftpService.list(path: path, session: session)
            updateRemoteFiles(files, path: path, tabID: tabID)
        } catch SFTPServiceError.unsupportedSession {
            updateRemoteFiles([], path: path, tabID: tabID)
            showNotification(kind: .warning, message: t.sftpUnsupportedForConnection)
        } catch {
            updateRemoteFiles([], path: path, tabID: tabID)
            showNotification(kind: .error, message: t.sftpRefreshFailed(String(describing: error)))
        }
    }

    func connectSFTPForSelectedTab() async {
        saveRemotePathForSelectedTab()

        guard
            let selectedTabID,
            let session = selectedSession
        else {
            remoteFiles = []
            return
        }

        guard
            let connection = session.sftpCredentialConnection,
            connection.authentication.kind == .password
        else {
            await refreshRemoteFiles(tabID: selectedTabID, path: remotePath, session: session)
            return
        }

        do {
            guard let credential = try await credentialStore.load(for: connection.id) else {
                requestSFTPCredential(tabID: selectedTabID, connection: connection, path: remotePath)
                updateRemoteFiles([], path: remotePath, tabID: selectedTabID)
                return
            }

            let sftpSession = try await connectWithTimeout(record: connection, credential: credential)
            attachSession(sftpSession, to: selectedTabID)
            pendingSFTPCredentialPrompt = nil
            await refreshRemoteFiles(tabID: selectedTabID, path: remotePath, session: sftpSession)
        } catch {
            updateRemoteFiles([], path: remotePath, tabID: selectedTabID)
            if isSSHAuthenticationFailure(error) {
                try? await credentialStore.delete(for: connection.id)
                requestSFTPCredential(tabID: selectedTabID, connection: connection, path: remotePath)
                showNotification(kind: .warning, message: t.authenticationFailedRetryPassword)
                return
            }

            showNotification(kind: .error, message: t.sftpRefreshFailed(String(describing: error)))
        }
    }

    func requestSFTPCredential(tabID: TerminalTab.ID, connection: ConnectionRecord, path: String) {
        guard pendingSFTPCredentialPrompt?.tabID != tabID else {
            return
        }

        pendingSFTPCredentialPrompt = SFTPCredentialPrompt(
            tabID: tabID,
            connection: connection,
            path: path
        )
    }

    func submitSFTPCredential(password: String, saveCredential: Bool = true) async {
        guard let prompt = pendingSFTPCredentialPrompt else {
            return
        }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else {
            return
        }

        do {
            let credential = Credential.password(trimmedPassword)
            let session = try await connectWithTimeout(record: prompt.connection, credential: credential)
            if saveCredential {
                try? await credentialStore.save(credential, for: prompt.connection.id)
            }
            attachSession(session, to: prompt.tabID)
            pendingSFTPCredentialPrompt = nil
            await refreshRemoteFiles(tabID: prompt.tabID, path: prompt.path, session: session)
        } catch {
            if isSSHAuthenticationFailure(error) {
                try? await credentialStore.delete(for: prompt.connection.id)
                requestSFTPCredential(tabID: prompt.tabID, connection: prompt.connection, path: prompt.path)
                showNotification(kind: .warning, message: t.authenticationFailedRetryPassword)
                return
            }

            showNotification(kind: .error, message: t.sftpRefreshFailed(String(describing: error)))
        }
    }

    func cancelSFTPCredentialPrompt() {
        pendingSFTPCredentialPrompt = nil
    }

    func openRemoteDirectory(_ file: RemoteFile) async {
        guard file.kind == .directory else {
            return
        }

        remotePath = file.path
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func openRemoteParentDirectory() async {
        guard remotePath != "." && remotePath != "/" else {
            return
        }

        let parent = URL(fileURLWithPath: remotePath).deletingLastPathComponent().path
        remotePath = parent == "/" || parent.isEmpty ? "." : parent
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func openRemotePath(_ path: String) async {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return
        }

        remotePath = trimmedPath
        saveRemotePathForSelectedTab()
        await refreshRemoteFiles()
    }

    func uploadFile(localPath: String) async {
        saveRemotePathForSelectedTab()
        await uploadFile(localPath: localPath, remoteDirectoryPath: remotePath)
    }

    func uploadFile(localPath: String, toRemoteDirectory directory: RemoteFile) async {
        guard directory.kind == .directory else {
            return
        }

        saveRemotePathForSelectedTab()
        await uploadFile(localPath: localPath, remoteDirectoryPath: directory.path)
    }

    func createRemoteDirectory(named name: String) async {
        saveRemotePathForSelectedTab()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let context = selectedSFTPContext,
            !trimmedName.isEmpty
        else {
            return
        }

        let path = joinedRemotePath(directory: context.path, name: trimmedName)
        do {
            try await sftpService.makeDirectory(remotePath: path, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .upload,
                localPath: "",
                remotePath: path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func deleteRemoteFile(_ file: RemoteFile) async {
        saveRemotePathForSelectedTab()
        guard let context = selectedSFTPContext else {
            return
        }

        do {
            try await sftpService.delete(remotePath: file.path, kind: file.kind, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .download,
                localPath: "",
                remotePath: file.path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func renameRemoteFile(_ file: RemoteFile, to newName: String) async {
        saveRemotePathForSelectedTab()
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let context = selectedSFTPContext,
            !trimmedName.isEmpty
        else {
            return
        }

        let parent = URL(fileURLWithPath: file.path).deletingLastPathComponent().path
        let newPath = joinedRemotePath(directory: parent == "/" ? "/" : parent, name: trimmedName)
        do {
            try await sftpService.rename(remotePath: file.path, to: newPath, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            recordFailedTransfer(
                direction: .download,
                localPath: "",
                remotePath: file.path,
                sessionID: context.tabID,
                message: String(describing: error)
            )
        }
    }

    func previewRemoteFile(_ file: RemoteFile) async {
        guard file.kind == .file, let context = selectedSFTPContext else {
            return
        }

        do {
            let text = try await sftpService.previewText(
                remotePath: file.path,
                byteLimit: 64 * 1024,
                session: context.session
            )
            filePreview = RemoteFilePreview(file: file, text: text)
        } catch {
            showNotification(kind: .error, message: t.previewFailed(String(describing: error)))
        }
    }

    func dismissFilePreview() {
        filePreview = nil
    }

    func changeRemoteFilePermissions(_ file: RemoteFile, modeText: String) async {
        saveRemotePathForSelectedTab()
        guard let context = selectedSFTPContext else {
            return
        }

        let trimmedMode = modeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedMode.isEmpty,
            let mode = UInt32(trimmedMode, radix: 8)
        else {
            showNotification(kind: .error, message: t.invalidPermissions)
            return
        }

        do {
            try await sftpService.changePermissions(remotePath: file.path, permissions: mode, session: context.session)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch {
            showNotification(kind: .error, message: t.permissionsChangeFailed(String(describing: error)))
        }
    }

    func uploadFile(localPath: String, remoteDirectoryPath: String) async {
        guard let context = selectedSFTPContext else {
            recordFailedTransfer(
                direction: .upload,
                localPath: localPath,
                remotePath: remoteDirectoryPath,
                message: t.noActiveSSHSession
            )
            return
        }

        let remoteFilePath = joinedRemotePath(
            directory: remoteDirectoryPath,
            name: URL(fileURLWithPath: localPath).lastPathComponent
        )
        let transfer = appendTransfer(
            direction: .upload,
            localPath: localPath,
            remotePath: remoteFilePath,
            sessionID: context.tabID
        )

        await runTrackedTransfer(transfer.id) {
            await self.runUploadTransfer(
                transfer.id,
                localPath: localPath,
                remotePath: remoteFilePath,
                context: context
            )
        }
    }

    func joinedRemotePath(directory: String, name: String) -> String {
        let trimmedDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDirectory.isEmpty || trimmedDirectory == "." {
            return name
        }

        if trimmedDirectory == "/" {
            return "/\(name)"
        }

        var normalizedDirectory = trimmedDirectory
        while normalizedDirectory.hasSuffix("/") {
            normalizedDirectory.removeLast()
        }
        return "\(normalizedDirectory)/\(name)"
    }

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
