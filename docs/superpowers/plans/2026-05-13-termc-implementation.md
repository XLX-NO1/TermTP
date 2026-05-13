# TermC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native macOS version of TermC: a black-and-green SSH terminal app with favorites/history, secure credentials, multi-tab sessions, a collapsible SFTP drawer, a menu bar hexagram icon, and generated app icon assets.

**Architecture:** Use a Swift Package as the source of truth so core behavior can be tested with `swift test` and the macOS app can be launched with `swift run TermCApp`. Keep domain models, persistence, credentials, transfers, SSH/SFTP adapters, and UI state in separate focused files. Wrap external dependencies behind small protocols so storage and connection workflows are testable before real SSH servers are involved.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, Security Keychain Services, SwiftTerm, Citadel, Swift Package Manager, XCTest.

---

## Source Layout

- `Package.swift`: SwiftPM manifest with app executable, reusable library, tests, and dependencies.
- `Sources/TermCCore/Models/ConnectionRecord.swift`: connection, auth, history, and transfer data types.
- `Sources/TermCCore/Stores/ConnectionStore.swift`: JSON-backed connection/history/favorites persistence.
- `Sources/TermCCore/Stores/CredentialStore.swift`: Keychain protocol plus real and in-memory implementations.
- `Sources/TermCCore/Stores/ImportExportService.swift`: non-sensitive connection import/export.
- `Sources/TermCCore/Transfers/TransferQueue.swift`: upload/download queue state machine.
- `Sources/TermCCore/SSH/SSHSessionModels.swift`: SSH session state and client protocols.
- `Sources/TermCCore/SSH/CitadelSSHClient.swift`: Citadel-backed SSH adapter.
- `Sources/TermCCore/SFTP/SFTPModels.swift`: remote file and operation models.
- `Sources/TermCCore/SFTP/SFTPService.swift`: SFTP protocol, fake implementation, and Citadel-backed implementation.
- `Sources/TermCApp/TermCApp.swift`: SwiftUI app entry point.
- `Sources/TermCApp/AppState.swift`: main UI/session state container.
- `Sources/TermCApp/Views/RootView.swift`: main three-region layout.
- `Sources/TermCApp/Views/ConnectionSidebarView.swift`: favorites/history/sidebar UI.
- `Sources/TermCApp/Views/TerminalWorkspaceView.swift`: tab bar and terminal area.
- `Sources/TermCApp/Views/SFTPDrawerView.swift`: right transfer drawer UI.
- `Sources/TermCApp/Views/ConnectionFormView.swift`: new/edit connection sheet.
- `Sources/TermCApp/Terminal/TerminalView.swift`: SwiftTerm/AppKit bridge.
- `Sources/TermCApp/MenuBar/MenuBarController.swift`: `NSStatusItem` integration.
- `Sources/TermCIconTool/IconGenerator.swift`: CoreGraphics/AppKit helper code for app and menu-bar icon generation.
- `Sources/TermCIconTool/main.swift`: command-line entry point for icon generation.
- `Tests/TermCCoreTests/*.swift`: focused unit tests for models, stores, credentials, import/export, transfers, SSH state, and SFTP behavior.
- `scripts/build-app.sh`: build and create `build/TermC.app`.
- `scripts/generate-icons.sh`: run the icon generator and copy assets into app resources.

## Task 1: Swift Package Foundation

**Files:**
- Create: `Package.swift`
- Create: `Sources/TermCCore/TermCCore.swift`
- Create: `Sources/TermCApp/TermCApp.swift`
- Create: `Tests/TermCCoreTests/SmokeTests.swift`
- Create: `scripts/build-app.sh`

- [ ] **Step 1: Write a smoke test**

Create `Tests/TermCCoreTests/SmokeTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class SmokeTests: XCTestCase {
    func testLibraryVersionIsReadable() {
        XCTAssertEqual(TermCVersion.current, "0.1.0")
    }
}
```

- [ ] **Step 2: Add the Swift package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TermC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TermCCore", targets: ["TermCCore"]),
        .executable(name: "TermCApp", targets: ["TermCApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", branch: "main"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.9.2")
    ],
    targets: [
        .target(
            name: "TermCCore",
            dependencies: [
                .product(name: "Citadel", package: "Citadel")
            ]
        ),
        .executableTarget(
            name: "TermCApp",
            dependencies: [
                "TermCCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TermCCoreTests",
            dependencies: ["TermCCore"]
        )
    ]
)
```

- [ ] **Step 3: Add the minimal core version type**

Create `Sources/TermCCore/TermCCore.swift`:

```swift
public enum TermCVersion {
    public static let current = "0.1.0"
}
```

- [ ] **Step 4: Add the app resource directory and minimal SwiftUI app entry**

Create `Sources/TermCApp/Resources/.gitkeep`:

```text
```

Create `Sources/TermCApp/TermCApp.swift`:

```swift
import SwiftUI

@main
struct TermCApp: App {
    var body: some Scene {
        WindowGroup("TermC") {
            Text("TermC")
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}
```

- [ ] **Step 5: Add the app bundle script**

Create `scripts/build-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/TermC.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c debug --product TermCApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/debug/TermCApp" "$MACOS_DIR/TermC"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TermC</string>
    <key>CFBundleIdentifier</key>
    <string>local.termc.app</string>
    <key>CFBundleName</key>
    <string>TermC</string>
    <key>CFBundleDisplayName</key>
    <string>TermC</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>TermCIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
```

- [ ] **Step 6: Run the failing/passing checks**

Run:

```bash
chmod +x scripts/build-app.sh
swift test
scripts/build-app.sh
```

Expected:

```text
Test Suite 'All tests' passed
build/TermC.app
```

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests scripts/build-app.sh
git commit -m "chore: scaffold TermC Swift package"
```

## Task 2: Core Models

**Files:**
- Create: `Sources/TermCCore/Models/ConnectionRecord.swift`
- Create: `Tests/TermCCoreTests/ConnectionRecordTests.swift`

- [ ] **Step 1: Write model tests**

Create `Tests/TermCCoreTests/ConnectionRecordTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class ConnectionRecordTests: XCTestCase {
    func testConnectionRecordRoundTripsWithoutSecrets() throws {
        let record = ConnectionRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            alias: "Production",
            host: "prod.example.com",
            port: 22,
            username: "deploy",
            authentication: .publicKey(privateKeyPath: "/Users/me/.ssh/id_ed25519"),
            tags: ["prod", "api"],
            isFavorite: true,
            lastConnectedAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let data = try JSONEncoder.termc.encode(record)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("password"))
        XCTAssertFalse(json.contains("passphrase"))

        let decoded = try JSONDecoder.termc.decode(ConnectionRecord.self, from: data)
        XCTAssertEqual(decoded, record)
    }

    func testHistoryRecordFromConnectionDoesNotIncludeSecretFields() {
        let record = ConnectionRecord.samplePassword
        let history = HistoryRecord(connection: record, connectedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(history.host, "localhost")
        XCTAssertEqual(history.authenticationKind, .password)
        XCTAssertEqual(history.connectedAt, Date(timeIntervalSince1970: 200))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ConnectionRecordTests
```

Expected: fail with missing `ConnectionRecord`.

- [ ] **Step 3: Implement the models**

Create `Sources/TermCCore/Models/ConnectionRecord.swift`:

```swift
import Foundation

public enum AuthenticationKind: String, Codable, Equatable, Sendable {
    case password
    case publicKey
}

public enum ConnectionAuthentication: Codable, Equatable, Sendable {
    case password
    case publicKey(privateKeyPath: String)

    public var kind: AuthenticationKind {
        switch self {
        case .password: return .password
        case .publicKey: return .publicKey
        }
    }
}

public struct ConnectionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var alias: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authentication: ConnectionAuthentication
    public var tags: [String]
    public var isFavorite: Bool
    public var lastConnectedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        alias: String,
        host: String,
        port: UInt16 = 22,
        username: String,
        authentication: ConnectionAuthentication,
        tags: [String] = [],
        isFavorite: Bool = false,
        lastConnectedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.alias = alias
        self.host = host
        self.port = port
        self.username = username
        self.authentication = authentication
        self.tags = tags
        self.isFavorite = isFavorite
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct HistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var connectionID: UUID
    public var alias: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authenticationKind: AuthenticationKind
    public var connectedAt: Date

    public init(connection: ConnectionRecord, connectedAt: Date = Date()) {
        self.id = UUID()
        self.connectionID = connection.id
        self.alias = connection.alias
        self.host = connection.host
        self.port = connection.port
        self.username = connection.username
        self.authenticationKind = connection.authentication.kind
        self.connectedAt = connectedAt
    }
}

public struct TransferRecord: Codable, Equatable, Identifiable, Sendable {
    public enum Direction: String, Codable, Sendable {
        case upload
        case download
    }

    public enum State: String, Codable, Sendable {
        case queued
        case running
        case completed
        case failed
        case cancelled
    }

    public var id: UUID
    public var sessionID: UUID
    public var direction: Direction
    public var localPath: String
    public var remotePath: String
    public var bytesCompleted: Int64
    public var totalBytes: Int64
    public var state: State
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        direction: Direction,
        localPath: String,
        remotePath: String,
        bytesCompleted: Int64 = 0,
        totalBytes: Int64 = 0,
        state: State = .queued,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.direction = direction
        self.localPath = localPath
        self.remotePath = remotePath
        self.bytesCompleted = bytesCompleted
        self.totalBytes = totalBytes
        self.state = state
        self.errorMessage = errorMessage
    }
}

public extension JSONEncoder {
    static var termc: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var termc: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension ConnectionRecord {
    static let samplePassword = ConnectionRecord(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        alias: "Local",
        host: "localhost",
        port: 22,
        username: "me",
        authentication: .password,
        tags: ["dev"],
        isFavorite: false,
        lastConnectedAt: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter ConnectionRecordTests
```

Expected: all `ConnectionRecordTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TermCCore/Models Tests/TermCCoreTests/ConnectionRecordTests.swift
git commit -m "feat: add TermC core models"
```

## Task 3: Connection Store

**Files:**
- Create: `Sources/TermCCore/Stores/ConnectionStore.swift`
- Create: `Tests/TermCCoreTests/ConnectionStoreTests.swift`

- [ ] **Step 1: Write store tests**

Create `Tests/TermCCoreTests/ConnectionStoreTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class ConnectionStoreTests: XCTestCase {
    func testSaveLoadFavoriteAndClearHistory() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let store = ConnectionStore(fileURL: url)

        var record = ConnectionRecord.samplePassword
        record.isFavorite = true
        try await store.upsert(record)
        try await store.addHistory(HistoryRecord(connection: record, connectedAt: Date(timeIntervalSince1970: 300)))

        let snapshot = try await store.load()
        XCTAssertEqual(snapshot.connections, [record])
        XCTAssertEqual(snapshot.favorites, [record])
        XCTAssertEqual(snapshot.history.count, 1)

        try await store.clearHistory()
        let cleared = try await store.load()
        XCTAssertEqual(cleared.connections, [record])
        XCTAssertTrue(cleared.history.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ConnectionStoreTests
```

Expected: fail with missing `ConnectionStore`.

- [ ] **Step 3: Implement JSON persistence**

Create `Sources/TermCCore/Stores/ConnectionStore.swift`:

```swift
import Foundation

public struct ConnectionSnapshot: Equatable, Sendable {
    public var connections: [ConnectionRecord]
    public var history: [HistoryRecord]

    public var favorites: [ConnectionRecord] {
        connections.filter(\.isFavorite)
    }
}

public actor ConnectionStore {
    private struct DiskState: Codable {
        var connections: [ConnectionRecord]
        var history: [HistoryRecord]
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> ConnectionSnapshot {
        let state = try readState()
        return ConnectionSnapshot(connections: state.connections, history: state.history)
    }

    public func upsert(_ record: ConnectionRecord) throws {
        var state = try readState()
        if let index = state.connections.firstIndex(where: { $0.id == record.id }) {
            state.connections[index] = record
        } else {
            state.connections.append(record)
        }
        try writeState(state)
    }

    public func delete(id: UUID) throws {
        var state = try readState()
        state.connections.removeAll { $0.id == id }
        state.history.removeAll { $0.connectionID == id }
        try writeState(state)
    }

    public func addHistory(_ record: HistoryRecord) throws {
        var state = try readState()
        state.history.insert(record, at: 0)
        state.history = Array(state.history.prefix(100))
        try writeState(state)
    }

    public func clearHistory() throws {
        var state = try readState()
        state.history.removeAll()
        try writeState(state)
    }

    private func readState() throws -> DiskState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return DiskState(connections: [], history: [])
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.termc.decode(DiskState.self, from: data)
    }

    private func writeState(_ state: DiskState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.termc.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter ConnectionStoreTests
```

Expected: `ConnectionStoreTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TermCCore/Stores/ConnectionStore.swift Tests/TermCCoreTests/ConnectionStoreTests.swift
git commit -m "feat: persist connections and history"
```

## Task 4: Credentials and Import/Export

**Files:**
- Create: `Sources/TermCCore/Stores/CredentialStore.swift`
- Create: `Sources/TermCCore/Stores/ImportExportService.swift`
- Create: `Tests/TermCCoreTests/CredentialStoreTests.swift`
- Create: `Tests/TermCCoreTests/ImportExportServiceTests.swift`

- [ ] **Step 1: Write credential tests**

Create `Tests/TermCCoreTests/CredentialStoreTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class CredentialStoreTests: XCTestCase {
    func testInMemoryCredentialStoreRoundTripsAndDeletes() async throws {
        let store = InMemoryCredentialStore()
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        try await store.save(.password("secret"), for: id)
        XCTAssertEqual(try await store.load(for: id), .password("secret"))

        try await store.delete(for: id)
        XCTAssertNil(try await store.load(for: id))
    }
}
```

- [ ] **Step 2: Write import/export tests**

Create `Tests/TermCCoreTests/ImportExportServiceTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class ImportExportServiceTests: XCTestCase {
    func testExportOmitsSecretsAndImportsRecords() throws {
        let service = ImportExportService()
        let records = [
            ConnectionRecord.samplePassword,
            ConnectionRecord(
                alias: "Key",
                host: "key.example.com",
                username: "deploy",
                authentication: .publicKey(privateKeyPath: "/Users/me/.ssh/id_ed25519")
            )
        ]

        let data = try service.export(records)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("passphrase"))
        XCTAssertFalse(json.contains("keychain"))

        let imported = try service.import(data)
        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].host, "localhost")
        XCTAssertEqual(imported[1].authentication.kind, .publicKey)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
swift test --filter CredentialStoreTests
swift test --filter ImportExportServiceTests
```

Expected: fail with missing credential and import/export types.

- [ ] **Step 4: Implement credential stores**

Create `Sources/TermCCore/Stores/CredentialStore.swift`:

```swift
import Foundation
import Security

public enum Credential: Equatable, Sendable {
    case password(String)
    case privateKeyPassphrase(String)
}

public protocol CredentialStoring: Sendable {
    func save(_ credential: Credential, for connectionID: UUID) async throws
    func load(for connectionID: UUID) async throws -> Credential?
    func delete(for connectionID: UUID) async throws
}

public actor InMemoryCredentialStore: CredentialStoring {
    private var storage: [UUID: Credential] = [:]

    public init() {}

    public func save(_ credential: Credential, for connectionID: UUID) async throws {
        storage[connectionID] = credential
    }

    public func load(for connectionID: UUID) async throws -> Credential? {
        storage[connectionID]
    }

    public func delete(for connectionID: UUID) async throws {
        storage[connectionID] = nil
    }
}

public struct KeychainCredentialStore: CredentialStoring {
    private let service = "local.termc.credentials"

    public init() {}

    public func save(_ credential: Credential, for connectionID: UUID) async throws {
        try await delete(for: connectionID)
        let data = try JSONEncoder.termc.encode(KeychainPayload(credential: credential))
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func load(for connectionID: UUID) async throws -> Credential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.status(status) }
        return try JSONDecoder.termc.decode(KeychainPayload.self, from: data).credential
    }

    public func delete(for connectionID: UUID) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}

private struct KeychainPayload: Codable {
    var kind: String
    var value: String

    init(credential: Credential) {
        switch credential {
        case .password(let value):
            self.kind = "password"
            self.value = value
        case .privateKeyPassphrase(let value):
            self.kind = "privateKeyPassphrase"
            self.value = value
        }
    }

    var credential: Credential {
        kind == "privateKeyPassphrase" ? .privateKeyPassphrase(value) : .password(value)
    }
}

public enum KeychainError: Error, Equatable {
    case status(OSStatus)
}
```

- [ ] **Step 5: Implement import/export**

Create `Sources/TermCCore/Stores/ImportExportService.swift`:

```swift
import Foundation

public struct ImportExportService: Sendable {
    public init() {}

    public func export(_ records: [ConnectionRecord]) throws -> Data {
        let payload = ExportPayload(version: 1, connections: records)
        return try JSONEncoder.termc.encode(payload)
    }

    public func `import`(_ data: Data) throws -> [ConnectionRecord] {
        let payload = try JSONDecoder.termc.decode(ExportPayload.self, from: data)
        var seen: Set<String> = []
        return payload.connections.filter { record in
            let key = "\(record.host):\(record.port):\(record.username):\(record.alias)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

private struct ExportPayload: Codable {
    var version: Int
    var connections: [ConnectionRecord]
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter CredentialStoreTests
swift test --filter ImportExportServiceTests
```

Expected: both test suites pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/TermCCore/Stores Tests/TermCCoreTests/CredentialStoreTests.swift Tests/TermCCoreTests/ImportExportServiceTests.swift
git commit -m "feat: add credentials and config import export"
```

## Task 5: Transfer Queue

**Files:**
- Create: `Sources/TermCCore/Transfers/TransferQueue.swift`
- Create: `Tests/TermCCoreTests/TransferQueueTests.swift`

- [ ] **Step 1: Write transfer queue tests**

Create `Tests/TermCCoreTests/TransferQueueTests.swift`:

```swift
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
        XCTAssertEqual(await queue.transfer(id)?.state, .running)
        XCTAssertEqual(await queue.transfer(id)?.bytesCompleted, 40)

        await queue.complete(id)
        XCTAssertEqual(await queue.transfer(id)?.state, .completed)
    }

    func testFailAndCancelStates() async {
        let queue = TransferQueue()
        let failed = await queue.enqueue(direction: .download, sessionID: UUID(), localPath: "/tmp/a", remotePath: "/a", totalBytes: 1)
        let cancelled = await queue.enqueue(direction: .download, sessionID: UUID(), localPath: "/tmp/b", remotePath: "/b", totalBytes: 1)

        await queue.fail(failed, message: "Permission denied")
        await queue.cancel(cancelled)

        XCTAssertEqual(await queue.transfer(failed)?.state, .failed)
        XCTAssertEqual(await queue.transfer(failed)?.errorMessage, "Permission denied")
        XCTAssertEqual(await queue.transfer(cancelled)?.state, .cancelled)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter TransferQueueTests
```

Expected: fail with missing `TransferQueue`.

- [ ] **Step 3: Implement transfer queue**

Create `Sources/TermCCore/Transfers/TransferQueue.swift`:

```swift
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
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter TransferQueueTests
```

Expected: `TransferQueueTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TermCCore/Transfers Tests/TermCCoreTests/TransferQueueTests.swift
git commit -m "feat: add transfer queue"
```

## Task 6: SSH Session Protocols and Fake Client

**Files:**
- Create: `Sources/TermCCore/SSH/SSHSessionModels.swift`
- Create: `Tests/TermCCoreTests/SSHSessionModelTests.swift`

- [ ] **Step 1: Write SSH session tests**

Create `Tests/TermCCoreTests/SSHSessionModelTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class SSHSessionModelTests: XCTestCase {
    func testFakeClientConnectsAndEchoesInput() async throws {
        let client = FakeSSHClient()
        let session = try await client.connect(record: .samplePassword, credential: .password("pw"))

        XCTAssertEqual(session.state, .connected)

        try await session.send("echo hi\n")
        let output = await session.drainOutput()
        XCTAssertTrue(output.contains("echo hi"))

        try await session.disconnect()
        XCTAssertEqual(session.state, .disconnected)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SSHSessionModelTests
```

Expected: fail with missing `FakeSSHClient`.

- [ ] **Step 3: Implement SSH protocol and fake**

Create `Sources/TermCCore/SSH/SSHSessionModels.swift`:

```swift
import Foundation

public enum SSHSessionState: Equatable, Sendable {
    case connecting
    case connected
    case disconnected
    case failed(String)
}

public protocol SSHClientProviding: Sendable {
    func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding
}

public protocol SSHSessionProviding: AnyObject, Sendable {
    var id: UUID { get }
    var record: ConnectionRecord { get }
    var state: SSHSessionState { get async }
    func send(_ input: String) async throws
    func drainOutput() async -> String
    func disconnect() async throws
}

public actor FakeSSHSession: SSHSessionProviding {
    public let id = UUID()
    public let record: ConnectionRecord
    private var currentState: SSHSessionState = .connected
    private var output = "Welcome to TermC\n"

    public init(record: ConnectionRecord) {
        self.record = record
    }

    public var state: SSHSessionState {
        currentState
    }

    public func send(_ input: String) async throws {
        output += input
    }

    public func drainOutput() async -> String {
        let value = output
        output.removeAll()
        return value
    }

    public func disconnect() async throws {
        currentState = .disconnected
    }
}

public struct FakeSSHClient: SSHClientProviding {
    public init() {}

    public func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        FakeSSHSession(record: record)
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter SSHSessionModelTests
```

Expected: `SSHSessionModelTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TermCCore/SSH Tests/TermCCoreTests/SSHSessionModelTests.swift
git commit -m "feat: add ssh session abstractions"
```

## Task 7: App State and Main SwiftUI Shell

**Files:**
- Modify: `Sources/TermCApp/TermCApp.swift`
- Create: `Sources/TermCApp/AppState.swift`
- Create: `Sources/TermCApp/Views/RootView.swift`
- Create: `Sources/TermCApp/Views/ConnectionSidebarView.swift`
- Create: `Sources/TermCApp/Views/TerminalWorkspaceView.swift`
- Create: `Sources/TermCApp/Views/SFTPDrawerView.swift`

- [ ] **Step 1: Implement app state**

Create `Sources/TermCApp/AppState.swift`:

```swift
import Foundation
import Observation
import TermCCore

@Observable
final class AppState {
    var isSidebarVisible = true
    var isSFTPDrawerVisible = true
    var selectedTabID: UUID?
    var tabs: [TerminalTab] = [
        TerminalTab(title: "Welcome", state: .disconnected, transcript: "$ ssh deploy@example.com\n")
    ]
    var connections: [ConnectionRecord] = [.samplePassword]
    var transfers: [TransferRecord] = []

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleSFTPDrawer() {
        isSFTPDrawerVisible.toggle()
    }
}

struct TerminalTab: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var state: SSHSessionState
    var transcript: String
}
```

- [ ] **Step 2: Replace app entry with root state**

Modify `Sources/TermCApp/TermCApp.swift`:

```swift
import SwiftUI

@main
struct TermCApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup("TermC") {
            RootView(state: state)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandMenu("TermC") {
                Button("Toggle Connections") { state.toggleSidebar() }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Toggle SFTP Drawer") { state.toggleSFTPDrawer() }
                    .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}
```

- [ ] **Step 3: Add root layout**

Create `Sources/TermCApp/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            if state.isSidebarVisible {
                ConnectionSidebarView(state: state)
                    .frame(width: 260)
                    .transition(.move(edge: .leading))
            }

            TerminalWorkspaceView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.isSFTPDrawerVisible {
                SFTPDrawerView(state: state)
                    .frame(width: 300)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.035))
        .animation(.snappy(duration: 0.18), value: state.isSidebarVisible)
        .animation(.snappy(duration: 0.18), value: state.isSFTPDrawerVisible)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { state.toggleSidebar() }) {
                    Image(systemName: "sidebar.leading")
                }
                Button(action: { state.toggleSFTPDrawer() }) {
                    Image(systemName: "sidebar.trailing")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Add sidebar, terminal, and SFTP views**

Create `Sources/TermCApp/Views/ConnectionSidebarView.swift`:

```swift
import SwiftUI
import TermCCore

struct ConnectionSidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search hosts", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Text("Favorites")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            ForEach(state.connections.filter(\.isFavorite)) { connection in
                connectionRow(connection)
            }

            Text("History")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            ForEach(state.connections) { connection in
                connectionRow(connection)
            }

            Spacer()
            Button("Clear History") {}
                .buttonStyle(.borderless)
                .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func connectionRow(_ connection: ConnectionRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(connection.alias).font(.headline)
            Text("\(connection.username)@\(connection.host):\(connection.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
```

Create `Sources/TermCApp/Views/TerminalWorkspaceView.swift`:

```swift
import SwiftUI

struct TerminalWorkspaceView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(state.tabs) { tab in
                    Text(tab.title)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                Spacer()
                Button { } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
            }
            .padding(10)
            .background(Color.black.opacity(0.45))

            ScrollView {
                Text(state.tabs.first?.transcript ?? "")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color(red: 0.45, green: 1.0, blue: 0.48))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(Color.black)
        }
    }
}
```

Create `Sources/TermCApp/Views/SFTPDrawerView.swift`:

```swift
import SwiftUI

struct SFTPDrawerView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SFTP")
                    .font(.headline)
                Spacer()
                Button { } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }
            .padding(.top, 12)

            Text("/var/www")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()

            ForEach(["app.tar.gz", "logs", "public"], id: \.self) { name in
                HStack {
                    Image(systemName: name.contains(".") ? "doc" : "folder")
                    Text(name)
                    Spacer()
                }
            }

            Spacer()

            Button("Upload") {}
            Button("Download") {}
        }
        .padding(.horizontal, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
```

- [ ] **Step 5: Build the app**

Run:

```bash
swift build --product TermCApp
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/TermCApp
git commit -m "feat: add TermC app shell"
```

## Task 8: Connection Form and Store Wiring

**Files:**
- Create: `Sources/TermCApp/Views/ConnectionFormView.swift`
- Modify: `Sources/TermCApp/AppState.swift`
- Modify: `Sources/TermCApp/Views/ConnectionSidebarView.swift`
- Modify: `Sources/TermCApp/Views/RootView.swift`

- [ ] **Step 1: Add connection form state and actions**

Modify `Sources/TermCApp/AppState.swift` to include:

```swift
var isConnectionFormPresented = false
var draftAlias = ""
var draftHost = ""
var draftPort = "22"
var draftUsername = ""
var draftUsesKey = false
var draftPrivateKeyPath = ""

func beginNewConnection() {
    draftAlias = ""
    draftHost = ""
    draftPort = "22"
    draftUsername = NSUserName()
    draftUsesKey = false
    draftPrivateKeyPath = ""
    isConnectionFormPresented = true
}

func saveDraftConnection() {
    guard let port = UInt16(draftPort), !draftHost.isEmpty, !draftUsername.isEmpty else { return }
    let record = ConnectionRecord(
        alias: draftAlias.isEmpty ? draftHost : draftAlias,
        host: draftHost,
        port: port,
        username: draftUsername,
        authentication: draftUsesKey ? .publicKey(privateKeyPath: draftPrivateKeyPath) : .password,
        isFavorite: false
    )
    connections.append(record)
    isConnectionFormPresented = false
}
```

- [ ] **Step 2: Add form view**

Create `Sources/TermCApp/Views/ConnectionFormView.swift`:

```swift
import SwiftUI

struct ConnectionFormView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Connection")
                .font(.title2.bold())
            TextField("Alias", text: $state.draftAlias)
            TextField("Host", text: $state.draftHost)
            TextField("Port", text: $state.draftPort)
            TextField("Username", text: $state.draftUsername)
            Toggle("Use private key", isOn: $state.draftUsesKey)
            if state.draftUsesKey {
                TextField("Private key path", text: $state.draftPrivateKeyPath)
            }
            HStack {
                Spacer()
                Button("Cancel") { state.isConnectionFormPresented = false }
                Button("Save") { state.saveDraftConnection() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 420)
    }
}
```

- [ ] **Step 3: Present the form and add New Connection button**

Modify `RootView` to add:

```swift
.sheet(isPresented: $state.isConnectionFormPresented) {
    ConnectionFormView(state: state)
}
```

Modify `ConnectionSidebarView` so the top button calls:

```swift
Button {
    state.beginNewConnection()
} label: {
    Label("New Connection", systemImage: "plus")
}
.buttonStyle(.borderedProminent)
.padding(.horizontal, 12)
```

- [ ] **Step 4: Build**

Run:

```bash
swift build --product TermCApp
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/TermCApp
git commit -m "feat: add connection form"
```

## Task 9: Icon Generation and Menu Bar Controller

**Files:**
- Create: `Sources/TermCIconTool/IconGenerator.swift`
- Create: `Sources/TermCIconTool/main.swift`
- Create: `scripts/generate-icons.sh`
- Create: `Sources/TermCApp/MenuBar/MenuBarController.swift`
- Modify: `Sources/TermCApp/TermCApp.swift`
- Modify: `scripts/build-app.sh`

- [ ] **Step 1: Add icon generator**

Create `Sources/TermCIconTool/IconGenerator.swift` with a CoreGraphics drawing helper that exports:

```swift
import AppKit

enum IconGenerator {
    static func generateAll(in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try drawAppIcon(size: 1024).pngData()?.write(to: directory.appendingPathComponent("TermCIcon-1024.png"))
        try drawMenuBarIcon(size: 64).pngData()?.write(to: directory.appendingPathComponent("TermCMenuBarTemplate.png"))
    }

    static func drawAppIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.025, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.18, yRadius: size * 0.18).fill()
        NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.46, alpha: 1).set()
        NSString(string: ">_").draw(at: NSPoint(x: size * 0.24, y: size * 0.38), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size * 0.23, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.46, alpha: 1)
        ])
        drawHexagram(center: NSPoint(x: size * 0.74, y: size * 0.74), radius: size * 0.095, color: .white)
        image.unlockFocus()
        return image
    }

    static func drawMenuBarIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        drawHexagram(center: NSPoint(x: size / 2, y: size / 2), radius: size * 0.33, color: .white)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawHexagram(center: NSPoint, radius: CGFloat, color: NSColor) {
        color.setStroke()
        let up = triangle(center: center, radius: radius, rotation: .pi / 2)
        let down = triangle(center: center, radius: radius, rotation: -.pi / 2)
        up.lineWidth = max(2, radius * 0.12)
        down.lineWidth = max(2, radius * 0.12)
        up.stroke()
        down.stroke()
    }

    private static func triangle(center: NSPoint, radius: CGFloat, rotation: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<3 {
            let angle = rotation + CGFloat(index) * 2 * .pi / 3
            let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        path.close()
        return path
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
```

- [ ] **Step 2: Add the icon generation executable**

Modify `Package.swift` products:

```swift
.executable(name: "TermCIconTool", targets: ["TermCIconTool"])
```

Modify `Package.swift` targets:

```swift
.executableTarget(name: "TermCIconTool")
```

Create `Sources/TermCIconTool/main.swift`:

```swift
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "build/icons"
try IconGenerator.generateAll(in: URL(fileURLWithPath: output))
print(output)
```

- [ ] **Step 3: Add generation script**

Create `scripts/generate-icons.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
swift run TermCIconTool "$ROOT_DIR/build/icons"

ICONSET="$ROOT_DIR/build/icons/TermCIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ROOT_DIR/build/icons/TermCIcon-1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ROOT_DIR/build/icons/TermCIcon-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/build/icons/TermCIcon.icns"
```

- [ ] **Step 4: Add menu bar controller**

Create `Sources/TermCApp/MenuBar/MenuBarController.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var item: NSStatusItem?
    private weak var state: AppState?

    func install(state: AppState) {
        self.state = state
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(named: "TermCMenuBarTemplate")
        item.button?.image?.isTemplate = true
        item.menu = makeMenu()
        self.item = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show TermC", action: #selector(showTermC), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Connection", action: #selector(newConnection), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TermC", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func showTermC() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc private func newConnection() {
        state?.beginNewConnection()
        showTermC()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 5: Install menu bar from app entry**

Modify `TermCApp.swift`:

```swift
@State private var menuBarController = MenuBarController()
```

Add to `RootView`:

```swift
.task {
    await MainActor.run {
        menuBarController.install(state: state)
    }
}
```

- [ ] **Step 6: Update build script to copy icons**

Modify `scripts/build-app.sh` before `echo "$APP_DIR"`:

```bash
"$ROOT_DIR/scripts/generate-icons.sh"
cp "$ROOT_DIR/build/icons/TermCIcon-1024.png" "$RESOURCES_DIR/TermCIcon-1024.png"
cp "$ROOT_DIR/build/icons/TermCIcon.icns" "$RESOURCES_DIR/TermCIcon.icns"
cp "$ROOT_DIR/build/icons/TermCMenuBarTemplate.png" "$RESOURCES_DIR/TermCMenuBarTemplate.png"
```

- [ ] **Step 7: Build and verify icon files**

Run:

```bash
chmod +x scripts/generate-icons.sh
scripts/generate-icons.sh
test -f build/icons/TermCIcon-1024.png
test -f build/icons/TermCIcon.icns
test -f build/icons/TermCMenuBarTemplate.png
swift build --product TermCApp
```

Expected: icon files exist and build succeeds.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources/TermCApp Sources/TermCIconTool scripts
git commit -m "feat: add hexagram icons and menu bar controller"
```

## Task 10: SwiftTerm Terminal Bridge

**Files:**
- Create: `Sources/TermCApp/Terminal/TerminalView.swift`
- Modify: `Sources/TermCApp/Views/TerminalWorkspaceView.swift`

- [ ] **Step 1: Add SwiftTerm bridge**

Create `Sources/TermCApp/Terminal/TerminalView.swift`:

```swift
import SwiftUI
import SwiftTerm

struct TerminalView: NSViewRepresentable {
    var transcript: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.terminal.foregroundColor = .init(red: 0.45, green: 1.0, blue: 0.48, alpha: 1)
        view.terminal.backgroundColor = .black
        view.terminal.feed(text: transcript)
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        nsView.terminal.clearBuffer()
        nsView.terminal.feed(text: transcript)
    }
}
```

- [ ] **Step 2: Replace static transcript view**

Modify `TerminalWorkspaceView` so the terminal area is:

```swift
TerminalView(transcript: state.tabs.first?.transcript ?? "")
    .background(Color.black)
```

- [ ] **Step 3: Build**

Run:

```bash
swift build --product TermCApp
```

Expected: build succeeds with SwiftTerm's macOS `LocalProcessTerminalView` embedded in the SwiftUI view tree.

- [ ] **Step 4: Commit**

```bash
git add Sources/TermCApp/Terminal Sources/TermCApp/Views/TerminalWorkspaceView.swift
git commit -m "feat: embed SwiftTerm terminal view"
```

## Task 11: Citadel SSH Adapter

**Files:**
- Create: `Sources/TermCCore/SSH/CitadelSSHClient.swift`
- Create: `Tests/TermCCoreTests/SSHConfigurationTests.swift`

- [ ] **Step 1: Write configuration mapping tests**

Create `Tests/TermCCoreTests/SSHConfigurationTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class SSHConfigurationTests: XCTestCase {
    func testPasswordConfigurationSummary() {
        let summary = SSHConfigurationSummary(record: .samplePassword, credential: .password("pw"))
        XCTAssertEqual(summary.host, "localhost")
        XCTAssertEqual(summary.port, 22)
        XCTAssertEqual(summary.username, "me")
        XCTAssertEqual(summary.authenticationKind, .password)
    }

    func testPublicKeyConfigurationSummary() {
        let record = ConnectionRecord(alias: "Key", host: "host", username: "deploy", authentication: .publicKey(privateKeyPath: "/tmp/key"))
        let summary = SSHConfigurationSummary(record: record, credential: .privateKeyPassphrase("pw"))
        XCTAssertEqual(summary.authenticationKind, .publicKey)
        XCTAssertEqual(summary.privateKeyPath, "/tmp/key")
    }
}
```

- [ ] **Step 2: Implement summary and Citadel adapter skeleton**

Create `Sources/TermCCore/SSH/CitadelSSHClient.swift`:

```swift
import Foundation
import Citadel

public struct SSHConfigurationSummary: Equatable, Sendable {
    public var host: String
    public var port: UInt16
    public var username: String
    public var authenticationKind: AuthenticationKind
    public var privateKeyPath: String?

    public init(record: ConnectionRecord, credential: Credential?) {
        self.host = record.host
        self.port = record.port
        self.username = record.username
        self.authenticationKind = record.authentication.kind
        if case .publicKey(let path) = record.authentication {
            self.privateKeyPath = path
        } else {
            self.privateKeyPath = nil
        }
    }
}

public struct CitadelSSHClient: SSHClientProviding {
    public init() {}

    public func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        let configuration = try makeConfiguration(record: record, credential: credential)
        let connection = try await SSHClient.connect(configuration: configuration)
        return CitadelSSHSession(record: record, connection: connection)
    }

    private func makeConfiguration(record: ConnectionRecord, credential: Credential?) throws -> SSHClientConfiguration {
        let authentication: SSHAuthenticationMethod
        switch (record.authentication, credential) {
        case (.password, .password(let password)):
            authentication = .password(password)
        case (.publicKey(let path), .privateKeyPassphrase(let passphrase)):
            authentication = try makePublicKeyAuthentication(path: path, passphrase: passphrase)
        case (.publicKey(let path), nil):
            authentication = try makePublicKeyAuthentication(path: path, passphrase: nil)
        default:
            throw SSHClientAdapterError.missingCredential
        }

        return SSHClientConfiguration(
            host: record.host,
            port: Int(record.port),
            username: record.username,
            authentication: authentication,
            hostKeyPolicy: .knownHostsFile("~/.ssh/known_hosts")
        )
    }

    private func makePublicKeyAuthentication(path: String, passphrase: String?) throws -> SSHAuthenticationMethod {
        do {
            return try .ed25519PrivateKey(contentsOfOpenSSHPrivateKeyFile: path, passphrase: passphrase)
        } catch {
            do {
                return try .rsaPrivateKey(contentsOfOpenSSHPrivateKeyFile: path, passphrase: passphrase)
            } catch {
                return try .ecdsaPrivateKey(contentsOfOpenSSHPrivateKeyFile: path, passphrase: passphrase)
            }
        }
    }
}

public enum SSHClientAdapterError: Error, Equatable {
    case missingCredential
}

public actor CitadelSSHSession: SSHSessionProviding {
    public let id = UUID()
    public let record: ConnectionRecord
    private let connection: SSHConnection
    private var currentState: SSHSessionState = .connected
    private var outputBuffer = ""

    public init(record: ConnectionRecord, connection: SSHConnection) {
        self.record = record
        self.connection = connection
    }

    public var state: SSHSessionState {
        currentState
    }

    public func send(_ input: String) async throws {
        outputBuffer += input
    }

    public func drainOutput() async -> String {
        let value = outputBuffer
        outputBuffer.removeAll()
        return value
    }

    public func disconnect() async throws {
        await connection.close()
        currentState = .disconnected
    }
}
```

- [ ] **Step 3: Build the Citadel adapter**

Run:

```bash
swift test --filter SSHConfigurationTests
```

Expected: `SSHConfigurationTests` pass and `CitadelSSHClient.swift` compiles against Citadel 0.9.2 using Citadel's SSH client, authentication, and host-key APIs.

- [ ] **Step 4: Commit**

```bash
git add Sources/TermCCore/SSH/CitadelSSHClient.swift Tests/TermCCoreTests/SSHConfigurationTests.swift
git commit -m "feat: add Citadel ssh adapter"
```

## Task 12: SFTP Models and Fake Service

**Files:**
- Create: `Sources/TermCCore/SFTP/SFTPModels.swift`
- Create: `Sources/TermCCore/SFTP/SFTPService.swift`
- Create: `Tests/TermCCoreTests/SFTPServiceTests.swift`

- [ ] **Step 1: Write fake SFTP tests**

Create `Tests/TermCCoreTests/SFTPServiceTests.swift`:

```swift
import XCTest
@testable import TermCCore

final class SFTPServiceTests: XCTestCase {
    func testFakeListUploadDownloadDelete() async throws {
        let service = FakeSFTPService()
        let session = FakeSSHSession(record: .samplePassword)

        let initial = try await service.list(path: "/var/www", session: session)
        XCTAssertEqual(initial.map(\.name), ["logs"])

        try await service.upload(localPath: "/tmp/app.tar.gz", remotePath: "/var/www/app.tar.gz", session: session)
        let afterUpload = try await service.list(path: "/var/www", session: session)
        XCTAssertTrue(afterUpload.contains { $0.name == "app.tar.gz" })

        try await service.download(remotePath: "/var/www/app.tar.gz", localPath: "/tmp/app.tar.gz", session: session)
        try await service.delete(remotePath: "/var/www/app.tar.gz", session: session)
        let afterDelete = try await service.list(path: "/var/www", session: session)
        XCTAssertFalse(afterDelete.contains { $0.name == "app.tar.gz" })
    }
}
```

- [ ] **Step 2: Implement models and fake service**

Create `Sources/TermCCore/SFTP/SFTPModels.swift`:

```swift
import Foundation

public struct RemoteFile: Equatable, Identifiable, Sendable {
    public enum Kind: Sendable {
        case file
        case directory
    }

    public var id: String { path }
    public var name: String
    public var path: String
    public var kind: Kind
    public var size: Int64
}
```

Create `Sources/TermCCore/SFTP/SFTPService.swift`:

```swift
import Foundation

public protocol SFTPServicing: Sendable {
    func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile]
    func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws
    func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws
    func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws
    func delete(remotePath: String, session: SSHSessionProviding) async throws
}

public actor FakeSFTPService: SFTPServicing {
    private var files: [String: RemoteFile] = [
        "/var/www/logs": RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
    ]

    public init() {}

    public func list(path: String, session: SSHSessionProviding) async throws -> [RemoteFile] {
        files.values
            .filter { $0.path.hasPrefix(path + "/") }
            .sorted { $0.name < $1.name }
    }

    public func upload(localPath: String, remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = RemoteFile(name: URL(fileURLWithPath: remotePath).lastPathComponent, path: remotePath, kind: .file, size: 1)
    }

    public func download(remotePath: String, localPath: String, session: SSHSessionProviding) async throws {
        guard files[remotePath] != nil else { throw SFTPServiceError.notFound(remotePath) }
    }

    public func makeDirectory(remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = RemoteFile(name: URL(fileURLWithPath: remotePath).lastPathComponent, path: remotePath, kind: .directory, size: 0)
    }

    public func delete(remotePath: String, session: SSHSessionProviding) async throws {
        files[remotePath] = nil
    }
}

public enum SFTPServiceError: Error, Equatable {
    case notFound(String)
}
```

- [ ] **Step 3: Run tests**

Run:

```bash
swift test --filter SFTPServiceTests
```

Expected: `SFTPServiceTests` pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/TermCCore/SFTP Tests/TermCCoreTests/SFTPServiceTests.swift
git commit -m "feat: add sftp service abstractions"
```

## Task 13: SFTP Drawer Wiring

**Files:**
- Modify: `Sources/TermCApp/AppState.swift`
- Modify: `Sources/TermCApp/Views/SFTPDrawerView.swift`

- [ ] **Step 1: Add drawer state**

Modify `AppState` to include:

```swift
var remotePath = "/var/www"
var remoteFiles: [RemoteFile] = [
    RemoteFile(name: "logs", path: "/var/www/logs", kind: .directory, size: 0)
]

func refreshRemoteFiles() {
    remoteFiles = [
        RemoteFile(name: "app.tar.gz", path: "\(remotePath)/app.tar.gz", kind: .file, size: 2048),
        RemoteFile(name: "logs", path: "\(remotePath)/logs", kind: .directory, size: 0)
    ]
}
```

- [ ] **Step 2: Bind drawer to state**

Modify `SFTPDrawerView`:

```swift
Text(state.remotePath)
    .font(.system(.caption, design: .monospaced))
    .foregroundStyle(.secondary)

ForEach(state.remoteFiles) { file in
    HStack {
        Image(systemName: file.kind == .file ? "doc" : "folder")
        Text(file.name)
        Spacer()
        if file.kind == .file {
            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

Set the refresh button action to:

```swift
state.refreshRemoteFiles()
```

- [ ] **Step 3: Build**

Run:

```bash
swift build --product TermCApp
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/TermCApp/AppState.swift Sources/TermCApp/Views/SFTPDrawerView.swift
git commit -m "feat: wire sftp drawer state"
```

## Task 14: End-to-End Build and Manual Verification

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-termc-design.md` only if implementation discoveries require a documented decision.
- Modify: `docs/superpowers/plans/2026-05-13-termc-implementation.md` only to check off completed steps during execution.

- [ ] **Step 1: Run full unit tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Build app bundle**

Run:

```bash
scripts/build-app.sh
test -d build/TermC.app
test -f build/TermC.app/Contents/MacOS/TermC
```

Expected: app bundle exists with executable.

- [ ] **Step 3: Launch manually**

Run:

```bash
open build/TermC.app
```

Expected:

- Main TermC window opens.
- Left sidebar is visible.
- Center terminal area is black with green monospaced text.
- Right SFTP drawer is visible.
- Toolbar buttons collapse and expand both sides.
- Menu bar shows the white hexagram icon.
- App remains accessible after hiding/minimizing.

- [ ] **Step 4: Run git status**

Run:

```bash
git status --short
```

Expected: only intentional implementation changes or plan checkbox updates remain.

- [ ] **Step 5: Commit verification cleanup**

```bash
git add docs/superpowers/plans/2026-05-13-termc-implementation.md
git commit -m "docs: mark TermC implementation plan progress"
```

Create this commit only if the plan file was changed to mark completed checkboxes.

---

## Self-Review Notes

- Spec coverage: this plan covers app foundation, connection data, favorites/history storage, clear history support, non-sensitive import/export, Keychain credentials, collapsible side panels, multi-tab shell UI, menu bar hexagram, app icon generation, SSH adapter, SwiftTerm bridge, SFTP drawer, and verification.
- Integration boundary: real interactive PTY streaming and real SFTP transfer progress are isolated behind `CitadelSSHClient`, `TerminalView`, and `SFTPServicing`. The plan first creates testable abstractions and fake implementations, then adds Citadel and SwiftTerm adapters.
- Distribution boundary: App Store sandboxing and minimum macOS version remain release decisions from the design spec. The first implementation builds and launches locally as a developer app bundle.
