import Foundation
import TermTPCore

extension AppState {
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
}
