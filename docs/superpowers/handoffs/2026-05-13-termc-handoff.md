# TermC Handoff

Date: 2026-05-13

## Current State

Development is paused after completing Task 11 from:

```text
docs/superpowers/plans/2026-05-13-termc-implementation.md
```

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
27397a7 feat: add Citadel ssh adapter
```

The worktree is clean at handoff time.

## Product Decisions

App name:

```text
TermC
```

Core direction:

- Native macOS app.
- SwiftUI + AppKit where needed.
- Terminal rendering through SwiftTerm.
- SSH/SFTP through Citadel.
- macOS-style dark chrome with black terminal surface and classic green terminal text.
- Main layout has collapsible left connection sidebar and collapsible right SFTP drawer.
- Connections support history, favorites, password auth, and private-key auth.
- File transfer is planned through SFTP after connection.
- App icon is a black terminal tile with green prompt marks and a white magic hexagram in the upper-right.
- Menu bar / tray icon should be a white hexagram.

## Why Traversio Changed To Citadel

The original design selected Traversio for SSH/SFTP. During Task 1, SwiftPM could not fetch the documented Traversio package URL:

```text
https://github.com/GitSwiftLLC/Traversio.git
```

GitHub returned `Repository not found`, and `git ls-remote` confirmed the repository was not visible to the current GitHub account.

The implementation was changed to Citadel:

```text
https://github.com/orlandos-nl/Citadel.git
```

Citadel is public, SwiftPM-fetchable, based on SwiftNIO SSH, and includes SSH/SFTP APIs. The spec and implementation plan have been updated to Citadel, but some plan snippets still contain stale pseudo APIs. When implementing Citadel tasks, inspect the checked-out Citadel source instead of trusting old sample code.

Current resolved Citadel version:

```text
0.12.1
```

Important actual Citadel APIs used in Task 11:

- `SSHClient.connect(host:port:authenticationMethod:hostKeyValidator:reconnect:)`
- `SSHAuthenticationMethod.passwordBased(username:password:)`
- `SSHAuthenticationMethod.rsa(username:privateKey:)`
- `SSHAuthenticationMethod.ed25519(username:privateKey:)`
- `SSHHostKeyValidator.acceptAnything()`
- `SSHClient.close() async throws`

## Completed Tasks

Task 1: Swift Package Foundation

```text
a05a5b5 chore: scaffold TermC Swift package
```

Task 2: Core Models

```text
469a3f2 feat: add TermC core models
```

Task 3: Connection Store

```text
2891873 feat: persist connections and history
```

Task 4: Credentials and Import/Export

```text
7a9dbab feat: add credentials and config import export
```

Task 5: Transfer Queue

```text
9f6f4ed feat: add transfer queue
```

Task 6: SSH Session Protocols and Fake Client

```text
183591b feat: add ssh session abstractions
```

Task 7: App State and Main SwiftUI Shell

```text
7fb5ede feat: add TermC app shell
```

Task 8: Connection Form

```text
8fd4367 feat: add connection form
cceafff fix: validate connection form inputs
```

Task 9: Icon Assets and Menu Bar Controller

```text
3cacfd2 feat: add hexagram icons and menu bar controller
bd8459f fix: refine TermC icon generation
da5c4a3 fix: package app resources
```

Task 10: SwiftTerm Terminal Bridge

```text
31186cf feat: embed SwiftTerm terminal view
75c0be6 fix: reset terminal before replay
```

Task 11: Citadel SSH Adapter

```text
27397a7 feat: add Citadel ssh adapter
```

Created:

- `Sources/TermCCore/SSH/CitadelSSHClient.swift`
- `Tests/TermCCoreTests/SSHConfigurationTests.swift`

Includes:

- `SSHConfigurationSummary`
- `CitadelSSHClient`
- `SSHClientAdapterError`
- `CitadelSSHSession`
- Password authentication mapping.
- RSA and Ed25519 private-key authentication mapping.
- Real Citadel connection and disconnect hooks.
- Skeletal `send` / `drainOutput` buffer only. Real interactive PTY streaming is still future work.

Task 11 spec review passed via subagent:

```text
Spec compliant
```

No separate code-quality review was completed before this handoff because the user requested an immediate stop for quota.

## Current Verification

Task 11 implementer reported:

```bash
swift test --filter SSHConfigurationTests
swift test
```

Result:

```text
SSHConfigurationTests passed.
Full swift test passed.
```

Spec reviewer independently reported:

```text
swift test --filter SSHConfigurationTests passed: 2 tests
swift test passed: 14 total tests across XCTest and Swift Testing surfaces
```

Recommended first command when resuming:

```bash
cd "/Users/suweichao/ssh终端工具/.worktrees/termc-implementation"
git status --short --branch
swift test
```

## Known Notes And Risks

- Task 11 uses `SSHHostKeyValidator.acceptAnything()` as a temporary adapter skeleton. This should be replaced by known-hosts or explicit trust handling before real production SSH usage.
- Task 11 adds `extension SSHClient: @retroactive @unchecked Sendable {}` so the Citadel client can be held by the actor-backed session under Swift 6 concurrency checks. Revisit this during code-quality review.
- Citadel adapter currently supports RSA and Ed25519 OpenSSH private keys. ECDSA is not wired yet.
- `CitadelSSHSession.send` and `drainOutput` are not connected to a real remote shell stream yet.
- Keychain wrapper compiles but only the in-memory credential store has tests so far.
- `.build/` must not be committed.

## Next Step

Resume with the missing Task 11 code-quality review first, then continue to:

```text
Task 12: SFTP Models and Fake Service
```

Task 12 files:

- `Sources/TermCCore/SFTP/SFTPModels.swift`
- `Sources/TermCCore/SFTP/SFTPService.swift`
- `Tests/TermCCoreTests/SFTPServiceTests.swift`

Follow the same Subagent-Driven flow:

1. Dispatch Task 11 code-quality reviewer for commit `27397a7`.
2. Fix any review issues if found.
3. Start Task 12 with TDD.
4. Run filtered tests and full `swift test`.
5. Commit each task separately.
