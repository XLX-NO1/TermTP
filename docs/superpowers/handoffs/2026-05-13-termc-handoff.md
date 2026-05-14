# TermC Handoff

Date: 2026-05-14

## Current State

Development is paused after completing the planned implementation through Task 14 verification from:

```text
docs/superpowers/plans/2026-05-13-termc-implementation.md
```

Work is in the isolated git worktree:

```text
/Users/suweichao/ssh终端工具/.worktrees/termc-implementation
```

Current branch:

```text
termc-implementation
```

Latest commit:

```text
ec5bc30 chore: refresh resolved SwiftTerm pin
```

The worktree was clean after final verification.

## Product Decisions

App name: `TermC`.

Direction:

- Native macOS app using SwiftUI plus AppKit where useful.
- Terminal rendering through SwiftTerm.
- SSH/SFTP through Citadel.
- macOS dark chrome with black terminal and classic green terminal text.
- Collapsible left connection sidebar and right SFTP drawer.
- History, favorites, password auth, private-key auth, file-transfer scaffolding.
- App icon: black terminal tile with green prompt marks and white magic hexagram in upper-right.
- Menu bar icon: white hexagram.

## Why Traversio Changed To Citadel

The original design selected Traversio. SwiftPM could not fetch:

```text
https://github.com/GitSwiftLLC/Traversio.git
```

GitHub returned `Repository not found`, and `git ls-remote` confirmed the repository was not visible. The implementation therefore switched to:

```text
https://github.com/orlandos-nl/Citadel.git
```

Citadel is public, SwiftPM-fetchable, SwiftNIO SSH based, and includes SSH/SFTP APIs. Some old plan snippets used stale pseudo APIs, so future Citadel work should inspect the checked-out source.

Current resolved Citadel version:

```text
0.12.1
```

## Completed Work

Important commits since this worktree began:

```text
a05a5b5 chore: scaffold TermC Swift package
469a3f2 feat: add TermC core models
2891873 feat: persist connections and history
7a9dbab feat: add credentials and config import export
9f6f4ed feat: add transfer queue
183591b feat: add ssh session abstractions
7fb5ede feat: add TermC app shell
8fd4367 feat: add connection form
cceafff fix: validate connection form inputs
3cacfd2 feat: add hexagram icons and menu bar controller
bd8459f fix: refine TermC icon generation
da5c4a3 fix: package app resources
31186cf feat: embed SwiftTerm terminal view
75c0be6 fix: reset terminal before replay
27397a7 feat: add Citadel ssh adapter
a4c2027 docs: update TermC handoff after Citadel adapter
85c7b13 fix: tighten Citadel adapter credential handling
534c361 feat: add sftp service abstractions
a16cf53 fix: tighten fake sftp directory semantics
fe3ce43 feat: wire sftp drawer state
c93be14 fix: replay terminal transcript after resize
7a6d5b0 fix: require explicit ssh host key policy
ec5bc30 chore: refresh resolved SwiftTerm pin
```

## Current Implementation Notes

- `CitadelSSHClient` now defaults to `SSHHostKeyPolicy.strict` and throws `hostKeyVerificationRequired` rather than silently accepting any host key.
- Insecure host-key acceptance is explicit opt-in via `.insecureAcceptAnyHostKey`.
- SwiftTerm is pinned to revision `73576f6f838414bab4c230cd1b56237bd16c3bbf` in `Package.swift` and `Package.resolved` no longer keeps the old branch pin.
- `CitadelSSHSession.send` and `drainOutput` remain skeletal buffer behavior. Real PTY streaming is future work.
- Citadel private-key auth currently handles RSA and Ed25519 OpenSSH keys. ECDSA parsing is still future work.
- SFTP service is still fake/in-memory but now behaves like a directory listing: direct children only, missing paths throw `.notFound`.
- `SFTPDrawerView` is wired to `AppState.remotePath` and `remoteFiles`.
- `TerminalView` replays the transcript after SwiftTerm column changes, fixing the vertical wrapped welcome text seen during manual verification.

## Verification Performed

Commands run successfully:

```bash
swift test
scripts/build-app.sh
test -d build/TermC.app
test -f build/TermC.app/Contents/MacOS/TermC
```

Latest observed test count:

```text
XCTest: 18 tests, 0 failures
Swift Testing: 4 tests, 0 failures
```

Manual app launch was performed with `open build/TermC.app`.
Observed:

- Main TermC window opens.
- Left connection sidebar appears.
- Center terminal is black with green text.
- Welcome text renders horizontally after resize fix.
- Right SFTP drawer appears with `/var/www` and `logs`.
- Toolbar buttons collapse left and right panels.
- App bundle exists with executable.

## Remaining Risks / Future Work

- Implement real host-key verification, such as known-hosts or TOFU fingerprint storage, before enabling real SSH by default.
- Connect `CitadelSSHSession.send` and output draining to a real interactive PTY stream.
- Replace placeholder `AppState.refreshRemoteFiles()` with calls into `SFTPServicing` and eventually real Citadel SFTP.
- Add real upload/download wiring and progress into the transfer queue.
- Keychain wrapper compiles, but only the in-memory credential store is unit tested.
- Add ECDSA private-key support if Citadel exposes or gains public OpenSSH ECDSA key parsing.

## Next Step

This branch is ready for the finishing workflow. Suggested options:

1. Merge `termc-implementation` into `main` locally.
2. Keep the worktree and branch for more manual testing.
3. Push and create a PR if a remote workflow is desired.
