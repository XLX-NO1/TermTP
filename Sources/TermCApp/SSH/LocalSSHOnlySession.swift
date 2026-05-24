import Foundation
import TermCCore

private extension ConnectionRecord {
    var hasJumpHost: Bool {
        jumpHost?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

extension ConnectionRecord {
    var requiresLocalSSHOnly: Bool {
        hasJumpHost
    }
}

actor LocalSSHOnlySession: SSHSessionProviding {
    let id = UUID()
    let record: ConnectionRecord

    init(record: ConnectionRecord) {
        self.record = record
    }

    var state: SSHSessionState {
        .connected
    }

    func send(_ input: String) async throws {}

    func drainOutput() async -> String {
        ""
    }

    func disconnect() async throws {}
}

extension SSHSessionProviding {
    var sftpCredentialConnection: ConnectionRecord? {
        (self as? LocalSSHOnlySession)?.record
    }
}
