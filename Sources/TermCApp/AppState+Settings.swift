import Foundation
import TermCCore

extension AppState {
    var trustedHostKeys: [AppHostKeyTrustStore.TrustedHostKey] {
        _ = trustedHostKeyRevision
        return hostKeyTrustStore.trustedHostKeys
    }

    func trustPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: true)
    }

    func rejectPendingHostKey() {
        hostKeyTrustStore.resolvePendingPrompt(trusted: false)
    }

    func removeTrustedHostKey(hostPort: String) {
        hostKeyTrustStore.removeTrustedKey(hostPort: hostPort)
        trustedHostKeyRevision += 1
    }

    func clearTrustedHostKeys() {
        hostKeyTrustStore.clearTrustedKeys()
        try? FileManager.default.removeItem(at: TermTPKnownHostsFile.defaultFileURL)
        trustedHostKeyRevision += 1
    }

    func showNotification(kind: AppNotification.Kind, message: String) {
        notification = AppNotification(kind: kind, message: message)
    }

    func dismissNotification() {
        notification = nil
    }

    func showSettings() {
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleSFTPDrawer() {
        isSFTPDrawerVisible.toggle()
    }

    func increaseTerminalFontSize() {
        terminalFontSize = min(TerminalFont.sizeOptions.last ?? terminalFontSize, terminalFontSize + 1)
    }

    func decreaseTerminalFontSize() {
        terminalFontSize = max(TerminalFont.sizeOptions.first ?? terminalFontSize, terminalFontSize - 1)
    }
}
