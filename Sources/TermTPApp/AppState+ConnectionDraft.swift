import Foundation
import TermTPCore

extension AppState {
    func makeDraftConnection() -> ConnectionRecord? {
        let alias = draftAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = draftGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKeyPath = draftPrivateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let jumpHost = draftJumpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultRemotePath = draftDefaultRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepAliveInterval = Int(draftKeepAliveInterval.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 30
        let keepAliveMaxCount = Int(draftKeepAliveMaxCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3
        let forwardLocalPort = UInt16(draftForwardLocalPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationPort = UInt16(draftForwardDestinationPort.trimmingCharacters(in: .whitespacesAndNewlines))
        let forwardDestinationHost = draftForwardDestinationHost.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let port = UInt16(draftPort.trimmingCharacters(in: .whitespacesAndNewlines)),
            port > 0,
            !host.isEmpty,
            !username.isEmpty,
            !draftUsesKey || !privateKeyPath.isEmpty,
            !draftKeepAliveEnabled || (keepAliveInterval > 0 && keepAliveMaxCount > 0),
            !draftForwardEnabled || forwardLocalPort != nil,
            !draftForwardEnabled || draftForwardDirection == .dynamic || (!forwardDestinationHost.isEmpty && forwardDestinationPort != nil)
        else {
            return nil
        }

        let authentication: ConnectionAuthentication = draftUsesKey
            ? .publicKey(privateKeyPath: privateKeyPath)
            : .password
        return ConnectionRecord(
            alias: alias.isEmpty ? host : alias,
            host: host,
            port: port,
            username: username,
            authentication: authentication,
            tags: parseTags(draftTags),
            group: group.isEmpty ? nil : group,
            keepAlive: .init(
                isEnabled: draftKeepAliveEnabled,
                intervalSeconds: keepAliveInterval,
                maxCount: keepAliveMaxCount
            ),
            jumpHost: jumpHost.isEmpty ? nil : jumpHost,
            portForwards: makeDraftPortForwards(
                localPort: forwardLocalPort,
                destinationHost: forwardDestinationHost,
                destinationPort: forwardDestinationPort
            ),
            defaultRemotePath: defaultRemotePath.isEmpty ? nil : defaultRemotePath
        )
    }

    func parseTags(_ value: String) -> [String] {
        value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func makeDraftPortForwards(
        localPort: UInt16?,
        destinationHost: String,
        destinationPort: UInt16?
    ) -> [ConnectionRecord.PortForward] {
        guard draftForwardEnabled, let localPort else {
            return []
        }

        return [
            .init(
                direction: draftForwardDirection,
                bindAddress: draftForwardBindAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                localPort: localPort,
                destinationHost: destinationHost,
                destinationPort: destinationPort ?? 0
            )
        ]
    }
}
