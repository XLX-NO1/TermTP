# TermC Handoff

Date: 2026-05-13

## Current State

Development is paused after completing Task 6 from `docs/superpowers/plans/2026-05-13-termc-implementation.md`.

Work is happening in an isolated git worktree:

```text
/Users/suweichao/ssh终端工具/.worktrees/termc-implementation
```

Current branch:

```text
termc-implementation
```

Latest commit:

```text
183591b feat: add ssh session abstractions
```

The main checkout at `/Users/suweichao/ssh终端工具` is not where implementation work is being done.

## Important Dependency Change

The original design and plan selected Traversio for SSH/SFTP. During Task 1, SwiftPM could not fetch the documented Traversio package URL:

```text
https://github.com/GitSwiftLLC/Traversio.git
```

GitHub returned `Repository not found`, and `git ls-remote` confirmed the repository was not visible to the current GitHub account.

The implementation was changed to use Citadel instead:

```text
https://github.com/orlandos-nl/Citadel.git
```

Citadel is public, SwiftPM-fetchable, based on SwiftNIO SSH, and includes SSH/SFTP-related APIs. The design spec and implementation plan in this worktree have already been updated from Traversio to Citadel.

## Completed Tasks

### Task 1: Swift Package Foundation

Completed and committed:

```text
a05a5b5 chore: scaffold TermC Swift package
```

Created:

- `Package.swift`
- `Package.resolved`
- `Sources/TermCCore/TermCCore.swift`
- `Sources/TermCApp/TermCApp.swift`
- `Sources/TermCApp/Resources/.gitkeep`
- `Tests/TermCCoreTests/SmokeTests.swift`
- `scripts/build-app.sh`

Verified:

```bash
swift test
scripts/build-app.sh
```

Result: tests passed and `build/TermC.app` was generated.

### Task 2: Core Models

Completed and committed:

```text
469a3f2 feat: add TermC core models
```

Created:

- `Sources/TermCCore/Models/ConnectionRecord.swift`
- `Tests/TermCCoreTests/ConnectionRecordTests.swift`

Includes:

- `ConnectionRecord`
- `ConnectionAuthentication`
- `AuthenticationKind`
- `HistoryRecord`
- `TransferRecord`
- `JSONEncoder.termc`
- `JSONDecoder.termc`
- `ConnectionRecord.samplePassword`

### Task 3: Connection Store

Completed and committed:

```text
2891873 feat: persist connections and history
```

Created:

- `Sources/TermCCore/Stores/ConnectionStore.swift`
- `Tests/TermCCoreTests/ConnectionStoreTests.swift`

Includes JSON-backed persistence for connections, favorites, and history clearing.

### Task 4: Credentials and Import/Export

Completed and committed:

```text
7a9dbab feat: add credentials and config import export
```

Created:

- `Sources/TermCCore/Stores/CredentialStore.swift`
- `Sources/TermCCore/Stores/ImportExportService.swift`
- `Tests/TermCCoreTests/CredentialStoreTests.swift`
- `Tests/TermCCoreTests/ImportExportServiceTests.swift`

Includes:

- `Credential`
- `CredentialStoring`
- `InMemoryCredentialStore`
- `KeychainCredentialStore`
- `ImportExportService`

Note: tests cover the in-memory credential store. The real Keychain wrapper compiles but is not yet integration-tested against macOS Keychain.

### Task 5: Transfer Queue

Completed and committed:

```text
9f6f4ed feat: add transfer queue
```

Created:

- `Sources/TermCCore/Transfers/TransferQueue.swift`
- `Tests/TermCCoreTests/TransferQueueTests.swift`

Includes actor-based queue state transitions for upload/download jobs.

### Task 6: SSH Session Protocols and Fake Client

Completed and committed:

```text
183591b feat: add ssh session abstractions
```

Created:

- `Sources/TermCCore/SSH/SSHSessionModels.swift`
- `Tests/TermCCoreTests/SSHSessionModelTests.swift`

Includes:

- `SSHSessionState`
- `SSHClientProviding`
- `SSHSessionProviding`
- `FakeSSHSession`
- `FakeSSHClient`

## Current Verification

Last full verification:

```bash
swift test
```

Result:

```text
Executed 9 tests, with 0 failures
```

## Git Status Note

At the time of this handoff, `.build/` is untracked in the worktree. It is ignored in the main repo ignore rules only through `build/`, not `.build/`. Do not commit `.build/`. Consider adding `.build/` to `.gitignore` in a later cleanup commit.

## Next Step

Resume at:

```text
Task 7: App State and Main SwiftUI Shell
```

Task 7 files to create or modify:

- `Sources/TermCApp/TermCApp.swift`
- `Sources/TermCApp/AppState.swift`
- `Sources/TermCApp/Views/RootView.swift`
- `Sources/TermCApp/Views/ConnectionSidebarView.swift`
- `Sources/TermCApp/Views/TerminalWorkspaceView.swift`
- `Sources/TermCApp/Views/SFTPDrawerView.swift`

Recommended first command when resuming:

```bash
cd "/Users/suweichao/ssh终端工具/.worktrees/termc-implementation"
git status --short --branch
swift test
```

Then continue with Task 7 from the implementation plan.

## Known Implementation Notes

- Swift 6/XCTest does not allow `await` inside `XCTAssertEqual` autoclosures. Existing tests use local variables before assertions. Keep this pattern in future async tests.
- `Package.resolved` currently resolves Citadel to `0.12.1` even though `Package.swift` requests from `0.9.2`. This is expected SwiftPM behavior because `from: "0.9.2"` allows compatible newer `0.x` versions according to SwiftPM's resolver rules for the package.
- The implementation plan still has future Task 11 named `Citadel SSH Adapter`, but its example code may need API adjustment against the actual Citadel `0.12.1` public API when that task is reached.
- The app UI is still the minimal Task 1 `Text("TermC")` window. No SwiftUI shell work has started yet.

