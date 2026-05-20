import Foundation
import TermCCore

extension AppState {
    var visibleTransfers: [TransferRecord] {
        guard let selectedTabID else {
            return []
        }

        let recentCompletionCutoff = Date().addingTimeInterval(-4)
        return transfers.filter {
            guard $0.sessionID == selectedTabID else {
                return false
            }

            switch $0.state {
            case .completed:
                return ($0.finishedAt ?? $0.updatedAt) >= recentCompletionCutoff
            case .cancelled:
                return false
            case .queued, .running, .failed:
                return true
            }
        }
    }

    func downloadFile(remoteFile: RemoteFile, localPath: String) async {
        guard let context = selectedSFTPContext else {
            recordFailedTransfer(
                direction: .download,
                localPath: localPath,
                remotePath: remoteFile.path,
                message: t.noActiveSSHSession
            )
            return
        }

        let workingPath = downloadWorkingPath(for: localPath)
        let resumeOffset = localFileSize(at: workingPath)
        let transfer = appendTransfer(
            direction: .download,
            localPath: localPath,
            remotePath: remoteFile.path,
            sessionID: context.tabID,
            bytesCompleted: resumeOffset,
            totalBytes: remoteFile.size
        )

        await runTrackedTransfer(transfer.id) {
            await self.runDownloadTransfer(
                transfer.id,
                remotePath: remoteFile.path,
                localPath: localPath,
                workingPath: workingPath,
                totalBytes: remoteFile.size,
                session: context.session
            )
        }
    }

    func cancelTransfer(_ id: TransferRecord.ID) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard transfers[index].state == .running || transfers[index].state == .queued else {
            return
        }

        transferTasks[id]?.cancel()
        transferTasks[id] = nil
        transfers[index].state = .cancelled
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = Date()
    }

    func clearFinishedTransfersForSelectedTab() {
        guard let selectedTabID else {
            return
        }

        transfers.removeAll {
            $0.sessionID == selectedTabID && ($0.state == .completed || $0.state == .cancelled)
        }
    }

    func retryTransfer(_ id: TransferRecord.ID) async {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }

        let transfer = transfers[index]
        guard transfer.state == .failed || transfer.state == .cancelled else {
            return
        }

        transfers[index].state = .running
        transfers[index].errorMessage = nil
        transfers[index].bytesCompleted = 0
        transfers[index].createdAt = Date()
        transfers[index].updatedAt = transfers[index].createdAt
        transfers[index].finishedAt = nil

        guard let context = sftpContext(for: transfer.sessionID) else {
            failTransfer(id, message: t.noActiveSSHSession)
            return
        }

        switch transfer.direction {
        case .download:
            await runTrackedTransfer(id) {
                await self.runDownloadTransfer(
                    id,
                    remotePath: transfer.remotePath,
                    localPath: transfer.localPath,
                    workingPath: self.downloadWorkingPath(for: transfer.localPath),
                    totalBytes: transfer.totalBytes,
                    session: context.session
                )
            }
        case .upload:
            await runTrackedTransfer(id) {
                await self.runUploadTransfer(
                    id,
                    localPath: transfer.localPath,
                    remotePath: transfer.remotePath,
                    context: context
                )
            }
        }
    }

    func appendTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        sessionID: TerminalTab.ID? = nil,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0
    ) -> TransferRecord {
        let transfer = TransferRecord(
            sessionID: sessionID ?? selectedTabID ?? UUID(),
            direction: direction,
            localPath: localPath,
            remotePath: remotePath,
            bytesCompleted: bytesCompleted,
            totalBytes: totalBytes,
            state: .running
        )
        transfers.append(transfer)
        return transfer
    }

    func runTrackedTransfer(
        _ id: TransferRecord.ID,
        operation: @escaping @MainActor () async -> Void
    ) async {
        let task = Task { @MainActor in
            await operation()
        }
        transferTasks[id] = task
        await task.value
        transferTasks[id] = nil
    }

    func runUploadTransfer(
        _ id: TransferRecord.ID,
        localPath: String,
        remotePath: String,
        context: SFTPContext
    ) async {
        do {
            try Task.checkCancellation()
            try await sftpService.upload(localPath: localPath, remotePath: remotePath, session: context.session)
            try Task.checkCancellation()
            completeTransfer(id)
            await refreshRemoteFiles(tabID: context.tabID, path: context.path, session: context.session)
        } catch is CancellationError {
            cancelTransfer(id)
        } catch {
            failTransfer(id, message: String(describing: error))
        }
    }

    func runDownloadTransfer(
        _ id: TransferRecord.ID,
        remotePath: String,
        localPath: String,
        workingPath: String,
        totalBytes: Int64,
        session: SSHSessionProviding
    ) async {
        let resumeOffset = localFileSize(at: workingPath)
        updateTransferProgress(id, bytesCompleted: resumeOffset, totalBytes: totalBytes)

        do {
            try Task.checkCancellation()
            try await sftpService.download(
                remotePath: remotePath,
                localPath: workingPath,
                resumeFrom: resumeOffset,
                progress: { [weak self] bytesCompleted, totalBytes in
                    await self?.updateTransferProgress(
                        id,
                        bytesCompleted: bytesCompleted,
                        totalBytes: totalBytes
                    )
                },
                session: session
            )
            try Task.checkCancellation()
            try finalizeDownload(workingPath: workingPath, destinationPath: localPath)
            completeTransfer(id)
        } catch is CancellationError {
            cancelTransfer(id)
        } catch {
            failTransfer(id, message: String(describing: error))
        }
    }

    func downloadWorkingPath(for destinationPath: String) -> String {
        destinationPath + ".termtp-download"
    }

    func finalizeDownload(workingPath: String, destinationPath: String) throws {
        let fileManager = FileManager.default
        let workingURL = URL(fileURLWithPath: workingPath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        if fileManager.fileExists(atPath: destinationPath) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: workingURL)
        } else {
            try fileManager.moveItem(at: workingURL, to: destinationURL)
        }
    }

    func recordFailedTransfer(
        direction: TransferRecord.Direction,
        localPath: String,
        remotePath: String,
        sessionID: TerminalTab.ID? = nil,
        message: String
    ) {
        transfers.append(TransferRecord(
            sessionID: sessionID ?? selectedTabID ?? UUID(),
            direction: direction,
            localPath: localPath,
            remotePath: remotePath,
            state: .failed,
            errorMessage: message
        ))
    }

    func completeTransfer(_ id: TransferRecord.ID) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].bytesCompleted = max(transfers[index].bytesCompleted, transfers[index].totalBytes)
        transfers[index].state = .completed
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = transfers[index].updatedAt
    }

    func updateTransferProgress(
        _ id: TransferRecord.ID,
        bytesCompleted: Int64,
        totalBytes: Int64
    ) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].bytesCompleted = bytesCompleted
        transfers[index].totalBytes = totalBytes
        transfers[index].updatedAt = Date()
    }

    func failTransfer(_ id: TransferRecord.ID, message: String) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard transfers[index].state != .cancelled else {
            return
        }

        transfers[index].state = .failed
        transfers[index].errorMessage = message
        transfers[index].updatedAt = Date()
        transfers[index].finishedAt = nil
    }

    func localFileSize(at path: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int64 ?? 0
    }
}
