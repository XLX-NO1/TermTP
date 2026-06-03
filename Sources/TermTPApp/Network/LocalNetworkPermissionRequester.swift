import Foundation
import Network

final class LocalNetworkPermissionRequester: @unchecked Sendable {
    static let shared = LocalNetworkPermissionRequester()

    private let lock = NSLock()
    private var browser: NWBrowser?
    private var hasRequested = false

    private init() {}

    func requestIfNeeded() {
        lock.lock()
        guard !hasRequested else {
            lock.unlock()
            return
        }
        hasRequested = true
        lock.unlock()

        request()
    }

    func request() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_ssh._tcp", domain: nil),
            using: parameters
        )

        lock.lock()
        self.browser?.cancel()
        self.browser = browser
        lock.unlock()

        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready, .failed, .cancelled:
                self?.stopSoon()
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { _, _ in }
        browser.start(queue: DispatchQueue(label: "local.termtp.local-network-permission"))
    }

    private func stopSoon() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.lock.lock()
            let browser = self?.browser
            self?.browser = nil
            self?.lock.unlock()
            browser?.cancel()
        }
    }
}
