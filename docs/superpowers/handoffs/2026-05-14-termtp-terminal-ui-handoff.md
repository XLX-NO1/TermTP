# TermTP Terminal and UI Handoff - 2026-05-14

## Current Workspace

- Worktree: `/Users/suweichao/ssh终端工具/.worktrees/termc-implementation`
- Branch: `termc-implementation`
- App name: `TermTP`
- SwiftPM package/targets/modules still use `TermC*`; do not rename internals unless explicitly planned.
- Latest committed baseline before today's uncommitted work: `1f639a6 fix: compact TermTP workspace layout`

## Important User Preferences

- Reply in Chinese.
- User is actively testing the built app and gives visual/behavior feedback.
- Prefer small iterative fixes over broad refactors.
- Do not silently remove or reset uncommitted work.
- App icon direction remains white magic circle / green terminal prompt unless user says otherwise.

## What Changed Today

Today's work is not committed yet.

### Window/UI polish

- Removed the fixed `RootView` width/height from `Sources/TermCApp/TermCApp.swift`.
  - This fixed the white strips at the sides when the window is resized.
- Moved sidebar/drawer collapse buttons to the far left in `Sources/TermCApp/Views/RootView.swift`.
- Enlarged those collapse buttons and made them easier to click.
- Reworked `Clear History` in `Sources/TermCApp/Views/ConnectionSidebarView.swift` so it is white text on a dark custom button.

### Connection flow

- `ConnectionFormView` now has a password field for password auth and the primary button says `Connect`.
- `AppState.connectDraftConnection()` now creates a connection record, creates/selects a tab, and attempts an SSH connection.
- Added a 10-second connection timeout so the UI does not stay forever in `connecting`.
- Added failure transcript text for connection errors.

### Host key trust

- Added `Sources/TermCCore/SSH/HostKeyTrustStore.swift`.
- `CitadelSSHClient` now supports a strict host key path using a custom prompting validator.
- `RootView` has a `Trust SSH Host Key?` alert wired to `AppState.pendingHostKeyPrompt`.
- Caveat: after switching the visible terminal to system `/usr/bin/ssh`, OpenSSH now handles the real interactive host-key prompt in the terminal. The TermCCore host-key prompt path is still useful for future Citadel/SFTP flows but is no longer the main visible terminal path.

### Real terminal behavior

- Root cause found: previous `TerminalView` only rendered a static transcript, and `CitadelSSHSession.send(_:)` only appended to local output. It never opened a remote shell/PTY.
- Added `Sources/TermCApp/Terminal/LocalSSHTerminalView.swift`.
- Connected SSH tabs now render `LocalSSHTerminalView`, which starts `/usr/bin/ssh` in a SwiftTerm `LocalProcessTerminalView`.
- This gives real interactive terminal behavior:
  - remote shell output appears in the terminal,
  - keyboard input goes to ssh,
  - OpenSSH handles password input and host-key confirmation,
  - SwiftTerm provides native copy/paste behavior.
- Caveat: the password entered in `ConnectionFormView` is not automatically passed to `/usr/bin/ssh`; the user should type the password in the terminal prompt. This is intentional for now and safer than scripting password entry.

### Tabs and connection list actions

- Added `AppState.closeTab(_:)`, `clearHistory()`, `deleteConnection(_:)`, `toggleFavorite(_:)`, and `sendInputToSelectedTab(_:)`.
- `TerminalWorkspaceView` now has a tab right-click menu with `Close`.
- `ConnectionSidebarView` now:
  - calls `clearHistory()` from the Clear History button,
  - adds right-click actions on connection rows:
    - `Add to Favorites` / `Remove from Favorites`,
    - `Delete`.
- Verified visually with Computer Use:
  - right-clicking Local connection showed `Add to Favorites` and `Delete`,
  - selecting `Delete` removed the Local history row.

## Current Uncommitted Files

As of this handoff, `git status --short` shows:

```text
 M Package.swift
 M Sources/TermCApp/AppState.swift
 M Sources/TermCApp/TermCApp.swift
 M Sources/TermCApp/Terminal/TerminalView.swift
 M Sources/TermCApp/Views/ConnectionFormView.swift
 M Sources/TermCApp/Views/ConnectionSidebarView.swift
 M Sources/TermCApp/Views/RootView.swift
 M Sources/TermCApp/Views/TerminalWorkspaceView.swift
 M Sources/TermCCore/SSH/CitadelSSHClient.swift
 M Tests/TermCAppTests/AppStateTests.swift
 M Tests/TermCCoreTests/SSHConfigurationTests.swift
?? Sources/TermCApp/Terminal/LocalSSHTerminalView.swift
?? Sources/TermCCore/SSH/HostKeyTrustStore.swift
```

This handoff file itself will also be uncommitted until staged/committed.

## Verification Already Run

Last full verification run succeeded:

```bash
swift test
scripts/build-app.sh
```

Observed results:

- XCTest suite: 19 tests, 0 failures.
- Swift Testing suite: 14 tests, 0 failures.
- App bundle built at:
  `/Users/suweichao/ssh终端工具/.worktrees/termc-implementation/build/TermTP.app`
- The app was opened after build and visually checked.

## Key Design Decision: Why System ssh for Visible Terminal

The user reported that connecting only displayed `Connected to ...` and did not show the remote host terminal.

Investigation showed:

- `Sources/TermCApp/Terminal/TerminalView.swift` only rendered static transcript text.
- `send(source:data:)` was previously empty, later only echoed input into the selected tab.
- `Sources/TermCCore/SSH/CitadelSSHClient.swift` did connect with Citadel, but `CitadelSSHSession.send(_:)` only appended to local output and did not open a remote shell.
- Citadel's convenient interactive APIs, `withPTY` / `withTTY`, are marked `@available(macOS 15.0, *)`.
- The app currently targets macOS 14.

Chosen short-term path:

- Use SwiftTerm's `LocalProcessTerminalView` to launch `/usr/bin/ssh`.
- This provides a real interactive SSH terminal immediately without raising the minimum macOS version.
- Keep Citadel code for connection modeling and future SFTP/background flows.

Known tradeoff:

- The app currently does a Citadel connection check and then starts a separate `/usr/bin/ssh` process for the visible terminal. This can cause two connection attempts.
- A future cleanup should either:
  - use system ssh as the only visible/session connection path, or
  - implement a macOS 14-compatible NIOSSH channel/PTY adapter and remove the system ssh shortcut.

## Suggested Next Steps

1. Do not start by rewriting the terminal stack. First open the app and test the current user flow.
2. Verify real SSH behavior manually:
   - New Connection,
   - enter host/username,
   - connect,
   - confirm OpenSSH host key in terminal if prompted,
   - type password in terminal,
   - run simple commands like `pwd`, `ls`, `exit`.
3. Decide whether to remove the Citadel pre-check for visible terminal tabs.
   - Current user experience may be confusing because form password is required, but system ssh will ask again in terminal.
   - If keeping system ssh for visible tabs, the form should probably not require password for password auth.
4. Persist host key trust and connection history/favorites to disk. Current AppState list is in-memory.
5. Add explicit close/cleanup for `LocalSSHTerminalView` processes when a tab closes, if SwiftUI teardown is not enough.
6. Add visual validation after any UI change:
   - `scripts/build-app.sh`
   - open `build/TermTP.app`
   - inspect with Computer Use.

## Warnings for Next Agent

- Do not assume today's changes are committed.
- Do not run destructive git commands.
- If committing, include this handoff plus all currently intended source/test changes, or explicitly split into logical commits.
- The app may currently show deleted sample history after restart depending on in-memory defaults. This is expected until persistence is implemented.
- `ConnectionFormView` requiring password conflicts with the current system ssh terminal path because the password is not passed to ssh. Fix this before polishing connection UX.

