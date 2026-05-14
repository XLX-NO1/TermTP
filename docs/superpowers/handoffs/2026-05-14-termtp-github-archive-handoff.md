# TermTP GitHub Archive Handoff - 2026-05-14

## Current State

- Workspace: `/Users/suweichao/ssh终端工具/.worktrees/termc-implementation`
- Branch: `termc-implementation`
- GitHub private repository: `https://github.com/XLX-NO1/TermTP`
- Repository visibility: `PRIVATE`
- Remote: `origin https://github.com/XLX-NO1/TermTP.git`
- Default remote branch: `termc-implementation`
- Latest pushed commit: `b7675f6 feat: build TermTP SSH terminal app`
- Current worktree status at archive time: clean

## User Preferences

- Reply in Chinese.
- User is actively testing the macOS app and prefers fast, small, practical fixes.
- App display name is `TermTP`.
- SwiftPM package/targets/modules still use `TermC*`; do not internally rename unless planned.
- Avoid broad rewrites unless needed. Preserve working behavior and iterate from user feedback.

## What Is Implemented

### App Identity and Icon

- App has been renamed visually to `TermTP`.
- App icon and menu bar icon use the magic-circle style requested by the user.
- Menu bar icon is normalized to a suitable tray size.

### Main UI

- macOS-style compact app window.
- Black terminal-style UI with green/white terminal styling.
- Right-side connection sidebar.
- Bottom SFTP/file drawer.
- Sidebar and bottom drawer can be collapsed.
- Top/bottom/side white strip issues were reduced during UI cleanup.
- Window defaults:
  - minimum width: `720`
  - minimum height: `560`
  - default width: `760`
  - default height: `620`
  - sidebar width: `190`
  - SFTP drawer height: `260`

### SSH Terminal

- Visible terminal uses SwiftTerm `LocalProcessTerminalView` launching system `/usr/bin/ssh`.
- Reason: Citadel connects, but its convenient interactive PTY APIs are macOS 15-only while this project targets macOS 14.
- Each SSH tab keeps its terminal view alive in a `ZStack`; switching tabs hides/shows instead of destroying the process.
- Right-click terminal menu supports `Copy` and `Paste`.
- Password auth uses OpenSSH askpass environment variables to avoid asking twice:
  - `SSH_ASKPASS`
  - `SSH_ASKPASS_REQUIRE=force`
  - `TERMTP_SSH_PASSWORD`
- Important caveat: this is still a hybrid architecture. Citadel is used for connection/SFTP paths, while the visible shell is system ssh.

### Host Key Trust

- Added `HostKeyTrustStore.swift`.
- Citadel host key prompts can be trusted.
- Trusted host keys are persisted in `UserDefaults` under `TermTP.trustedHostKeys`.
- System ssh also uses `StrictHostKeyChecking=accept-new` for the visible terminal process.

### Connection History and Favorites

- History/favorites are no longer in-memory only.
- Connection records persist to:
  `/Users/suweichao/Library/Application Support/TermTP/connections.json`
- New connection form:
  - default username is empty,
  - supports password or private key fields,
  - primary action is `Connect`.
- Sidebar supports:
  - New Connection,
  - search,
  - favorites/history sections,
  - clear history,
  - right-click add/remove favorite,
  - right-click delete.

### Tabs

- Connection tabs can be right-clicked and closed.
- Tab switching should keep previous SSH sessions alive.

### SFTP / File Transfer

- Bottom SFTP panel lists files from the connected machine.
- Default remote path is `.` so it opens the login/default directory rather than assuming `/var/www`.
- Path bar is editable:
  - type a path,
  - press Return,
  - it jumps and refreshes.
- Parent directory button exists.
- Directory double-click opens it.
- Right-click actions:
  - whole SFTP panel: `Upload Here`, `Refresh`
  - path/list background: `Upload Here`, `Refresh`
  - directory: `Open`, `Upload Here`
  - file: `Download`
- Upload/download buttons were intentionally removed per user request.
- Download supports progress and resume:
  - if the local target file already exists, download resumes from existing byte size.
  - progress updates `TransferRecord.bytesCompleted` and `totalBytes`.
- Transfer progress rows only show for non-completed transfers; completed progress bars disappear so they do not block the file list.

## Key Architectural Decision: Why Citadel -> System SSH for Terminal

The user originally reported that after connecting the app only showed `Connected to ...` and did not show the remote terminal.

Root cause:

- The original terminal view rendered a local transcript only.
- Citadel connection succeeded, but no remote PTY/shell was opened.
- Citadel's convenient `withPTY` / `withTTY` APIs are marked macOS 15-only.
- Current project target is macOS 14.

Decision:

- Use system `/usr/bin/ssh` for the visible interactive terminal, hosted inside SwiftTerm.
- Keep Citadel for SFTP and connection service work.

Tradeoff:

- There are effectively two SSH paths:
  - system ssh for visible shell,
  - Citadel for SFTP/file operations.
- This works for current user testing, but a later architecture cleanup should unify the session model.

## Verification at Archive Time

Last verified before pushing commit `b7675f6`:

```bash
swift test
```

Result:

- XCTest: 19 tests, 0 failures.
- Swift Testing: 25 tests, 0 failures.

Last app build command used repeatedly during testing:

```bash
scripts/build-app.sh
```

Output app:

```text
/Users/suweichao/ssh终端工具/.worktrees/termc-implementation/build/TermTP.app
```

## GitHub Upload

Created private GitHub repo:

```text
https://github.com/XLX-NO1/TermTP
```

Pushed branch:

```text
termc-implementation
```

Latest pushed commit:

```text
b7675f6 feat: build TermTP SSH terminal app
```

## Known Caveats / Next Suggested Work

1. Hybrid SSH architecture remains the largest technical debt.
   - System ssh owns the interactive shell.
   - Citadel owns SFTP.
   - Future cleanup should unify this if possible.

2. SFTP transfer cancellation is not implemented yet.
   - Progress and resume exist for download.
   - Pause/cancel/retry UI is a likely next improvement.

3. Upload resume/progress is still less complete than download.
   - Current upload calls the service and refreshes files.
   - Download has stronger progress/resume behavior.

4. Error visibility can improve.
   - Failed transfers are shown as failed rows, but there is no detailed error popover or retry menu.

5. Manual UI testing remains important.
   - User is testing on real hosts.
   - After future changes, run `scripts/build-app.sh`, open the app, and test real SSH + SFTP behavior.

## Important Warnings for Next Agent

- Do not assume the old handoff `2026-05-14-termtp-terminal-ui-handoff.md` is current; it predates the GitHub archive and contains stale notes about uncommitted work.
- Do not run destructive git commands.
- Do not delete or rewrite the private GitHub repo unless the user explicitly requests it.
- Before claiming completion, run fresh verification.
- Keep responding in Chinese.
