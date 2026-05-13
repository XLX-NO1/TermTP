import XCTest
@testable import TermCCore

final class TransferQueueTests: XCTestCase {
    func testTransferLifecycle() async {
        let queue = TransferQueue()
        let sessionID = UUID()

        let id = await queue.enqueue(
            direction: .upload,
            sessionID: sessionID,
            localPath: "/tmp/app.tar.gz",
            remotePath: "/var/www/app.tar.gz",
            totalBytes: 100
        )

        await queue.markRunning(id)
        await queue.updateProgress(id, bytesCompleted: 40)
        let runningTransfer = await queue.transfer(id)
        XCTAssertEqual(runningTransfer?.state, .running)
        XCTAssertEqual(runningTransfer?.bytesCompleted, 40)

        await queue.complete(id)
        let completedTransfer = await queue.transfer(id)
        XCTAssertEqual(completedTransfer?.state, .completed)
    }

    func testFailAndCancelStates() async {
        let queue = TransferQueue()
        let failed = await queue.enqueue(direction: .download, sessionID: UUID(), localPath: "/tmp/a", remotePath: "/a", totalBytes: 1)
        let cancelled = await queue.enqueue(direction: .download, sessionID: UUID(), localPath: "/tmp/b", remotePath: "/b", totalBytes: 1)

        await queue.fail(failed, message: "Permission denied")
        await queue.cancel(cancelled)

        let failedTransfer = await queue.transfer(failed)
        let cancelledTransfer = await queue.transfer(cancelled)
        XCTAssertEqual(failedTransfer?.state, .failed)
        XCTAssertEqual(failedTransfer?.errorMessage, "Permission denied")
        XCTAssertEqual(cancelledTransfer?.state, .cancelled)
    }
}
