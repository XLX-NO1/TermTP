import Foundation

public actor TransferQueue {
    private var transfers: [UUID: TransferRecord] = [:]
    private var order: [UUID] = []

    public init() {}

    @discardableResult
    public func enqueue(
        direction: TransferRecord.Direction,
        sessionID: UUID,
        localPath: String,
        remotePath: String,
        totalBytes: Int64
    ) -> UUID {
        let record = TransferRecord(
            sessionID: sessionID,
            direction: direction,
            localPath: localPath,
            remotePath: remotePath,
            totalBytes: totalBytes
        )
        transfers[record.id] = record
        order.append(record.id)
        return record.id
    }

    public func allTransfers() -> [TransferRecord] {
        order.compactMap { transfers[$0] }
    }

    public func transfer(_ id: UUID) -> TransferRecord? {
        transfers[id]
    }

    public func markRunning(_ id: UUID) {
        mutate(id) { $0.state = .running }
    }

    public func updateProgress(_ id: UUID, bytesCompleted: Int64) {
        mutate(id) { $0.bytesCompleted = bytesCompleted }
    }

    public func complete(_ id: UUID) {
        mutate(id) {
            $0.bytesCompleted = max($0.bytesCompleted, $0.totalBytes)
            $0.state = .completed
        }
    }

    public func fail(_ id: UUID, message: String) {
        mutate(id) {
            $0.state = .failed
            $0.errorMessage = message
        }
    }

    public func cancel(_ id: UUID) {
        mutate(id) { $0.state = .cancelled }
    }

    private func mutate(_ id: UUID, _ update: (inout TransferRecord) -> Void) {
        guard var record = transfers[id] else { return }
        update(&record)
        transfers[id] = record
    }
}
