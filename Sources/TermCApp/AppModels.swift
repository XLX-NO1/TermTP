import Foundation
import TermCCore

struct AppNotification: Identifiable, Equatable {
    enum Kind: Equatable {
        case info
        case warning
        case error
    }

    var id = UUID()
    var kind: Kind
    var message: String
}

struct SSHConnectionTimeoutError: Error, Equatable, CustomStringConvertible {
    var message: String

    var description: String {
        message
    }
}

struct TerminalTab: Identifiable, Equatable {
    var id: UUID
    var title: String
    var state: SSHSessionState
    var transcript: String
    var remotePath: String
    var localProcess: TerminalLocalProcess?
    var session: SSHSessionProviding?

    init(
        id: UUID = UUID(),
        title: String,
        state: SSHSessionState,
        transcript: String,
        remotePath: String = ".",
        localProcess: TerminalLocalProcess? = nil,
        session: SSHSessionProviding? = nil
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.transcript = transcript
        self.remotePath = remotePath
        self.localProcess = localProcess
        self.session = session
    }

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.state == rhs.state
            && lhs.transcript == rhs.transcript
            && lhs.remotePath == rhs.remotePath
            && lhs.localProcess == rhs.localProcess
    }
}

struct TerminalCommand: Identifiable, Equatable {
    var id = UUID()
    var text: String
}

struct RemoteFilePreview: Identifiable, Equatable {
    var id = UUID()
    var file: RemoteFile
    var text: String
}

struct SFTPCredentialPrompt: Identifiable, Equatable {
    var id = UUID()
    var tabID: TerminalTab.ID
    var connection: ConnectionRecord
    var path: String
}

enum TerminalLocalProcess: Equatable {
    case ssh(ConnectionRecord, credential: Credential?)
}

extension TerminalTab {
    static let welcome = TerminalTab(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: AppStrings(language: .zhHans).welcomeTitle,
        state: .disconnected,
        transcript: AppStrings(language: .zhHans).welcomeMessage
    )
}
