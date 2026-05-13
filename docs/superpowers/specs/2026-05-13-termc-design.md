# TermC Design Spec

Date: 2026-05-13

## Summary

TermC is a native macOS SSH terminal app for developers and operators who want a focused terminal-first workflow with built-in connection management and file transfer. It uses a macOS-native interface, a classic black terminal with green text, local connection history and favorites, secure credential storage through Keychain, multi-tab SSH sessions, a collapsible SFTP transfer drawer, and a menu bar presence.

The first version prioritizes a polished native Mac experience over cross-platform reach. The app should feel like a serious terminal tool: fast to open, quiet while working, easy to restore from the menu bar, and visually recognizable through a terminal-window app icon with a small magic hexagram accent.

## Product Decisions

- App name: TermC.
- Platform: native macOS app.
- UI style: macOS window chrome, restrained tool surfaces, black terminal background, green terminal text.
- Main layout: professional workstation layout with three regions.
- Side panels: both the left connection panel and the right SFTP drawer can collapse independently.
- SSH authentication: password and public-key authentication are both in scope for the first version.
- Credentials: passwords and private-key passphrases are stored in macOS Keychain.
- Connection data: history and favorites are stored locally.
- History: users can clear history.
- Migration: users can import and export non-sensitive connection configuration.
- Sessions: one main window supports multiple SSH tabs.
- File transfer: the right drawer provides SFTP upload and download for the active SSH connection.
- Menu bar: the app can minimize to the menu bar and expose quick actions there.
- Icon: app icon is a classic terminal window with a small magic hexagram at the upper-right corner; menu bar icon is a white hexagram template symbol.

## User Experience

### App Shell

TermC opens into one primary window. The default arrangement is:

- Left sidebar: connection search, favorites, and recent history.
- Center workspace: multi-tab terminal area.
- Right drawer: SFTP browser and transfer queue for the active tab.

The terminal remains the visual and interaction center. Side panels should feel useful but optional. Each side can be collapsed to a narrow icon rail or hidden state so users can work in a nearly full-width terminal when needed.

The window supports standard macOS behaviors: close, minimize, full screen, system menu commands, keyboard focus management, and native file pickers.

### Left Connection Panel

The left panel contains:

- Search field for host, alias, username, and tags.
- Favorites section.
- Recent history section.
- New connection button.
- Edit, duplicate, delete, favorite, and clear-history actions.

Connection rows show a concise label, host, username, authentication type, and favorite state. Sensitive values are never shown in the list.

When collapsed, the sidebar keeps a compact affordance for reopening it and may show a small favorites shortcut list if space allows.

### Terminal Tabs

The center workspace supports multiple SSH sessions in one window. Each tab represents one connected or connecting host. Tabs show:

- Connection alias or host.
- Connection state.
- Dirty/disconnected state when relevant.

Users can create a new tab from a favorite, history item, or manual connection form. Closing a connected tab asks for confirmation if an interactive shell is active. Disconnected tabs show a reconnect action.

The terminal view uses SwiftTerm for terminal emulation. TermC forwards keyboard input, paste events, resize events, and remote output between the SSH shell channel and the terminal view.

### Right SFTP Drawer

The SFTP drawer belongs to the active tab. It can be opened or closed without interrupting the terminal session.

The first version includes:

- Current remote path.
- Remote file list.
- Upload from local file picker.
- Download to local folder picker.
- New folder.
- Delete.
- Refresh.
- Transfer queue with progress, success, failure, and cancel states.

The drawer should avoid becoming a full two-pane file manager in version one. Local file selection uses native macOS file pickers, keeping the main interface compact and terminal-first.

### Menu Bar Behavior

TermC creates an `NSStatusItem` while running. Users can minimize or hide the main window and continue to access TermC from the menu bar.

The menu bar menu includes:

- Show or hide TermC.
- Quick connect to favorites.
- Open new connection.
- Recent connections.
- Preferences.
- Quit.

The menu bar icon is a white hexagram template image so macOS can render it correctly in light mode, dark mode, and highlighted menu states.

## Visual Design

### Main UI

The visual direction is a professional workstation:

- macOS-native window structure.
- Dark app chrome around the terminal.
- Classic black terminal canvas.
- Green terminal foreground as the signature color.
- Subtle borders and separators for side panels.
- Small, dense controls appropriate for a repeated-use developer tool.

The app should not look like a marketing page or a decorative dashboard. It should look like a utility that users can leave open all day.

### App Icon

The app icon is a macOS rounded-square icon with:

- Dark terminal-window base.
- Green `>_` terminal prompt.
- Subtle terminal window frame.
- Small magic hexagram in the upper-right corner as the TermC brand mark.

The hexagram should be clear at app icon sizes but not overpower the terminal prompt. It functions as a distinctive brand mark, not as a large decorative illustration.

### Menu Bar Icon

The menu bar icon is a simplified white hexagram. It should be delivered as a template image so macOS can tint it for system states. It must remain legible at small sizes and should avoid fine interior detail that disappears in the menu bar.

## Architecture

### Technology Stack

- SwiftUI for the app shell, panels, tabs, forms, settings, and general UI.
- AppKit bridges for menu bar integration, window control, native file panels, and terminal embedding details when SwiftUI alone is not sufficient.
- SwiftTerm for terminal emulation.
- Traversio for SSH shell sessions, SFTP, password authentication, public-key authentication, host-key trust, and related SSH workflows.
- Keychain Services for sensitive credential storage.
- Local JSON or a lightweight local persistence layer for non-sensitive connection metadata and UI preferences.

Traversio is selected because it is a native Swift SSH and SFTP client library for Apple platforms, and its documented surface covers shell, command, authentication, host-key trust, and SFTP workflows. SwiftTerm is selected because it provides embeddable VT100/Xterm terminal emulation for Swift apps.

### Core Modules

`TermCApp`

Owns app lifecycle, menu bar setup, window scene configuration, global commands, and dependency injection.

`ConnectionStore`

Stores and retrieves non-sensitive connection records, favorites, history, tags, import/export data, and UI ordering. It does not store passwords or private-key passphrases.

`CredentialStore`

Wraps Keychain access. It stores credentials by stable connection identity and supports create, read, update, delete, and migration-safe lookup.

`SSHSessionManager`

Creates, tracks, reconnects, and closes SSH sessions. It owns session state for each tab and exposes terminal IO streams to the UI layer.

`TerminalSessionView`

Embeds SwiftTerm, binds it to one SSH shell channel, handles keyboard input, paste, resize, scrollback behavior, and terminal theme.

`SFTPService`

Provides remote listing, upload, download, delete, mkdir, refresh, cancellation, and progress reporting for the active SSH connection.

`TransferQueue`

Tracks file transfer jobs across active sessions, including queued, running, completed, failed, and canceled states.

`HostKeyTrustStore`

Tracks known host keys and presents trust decisions when connecting to new or changed hosts.

`ImportExportService`

Reads and writes non-sensitive connection configuration. Exported files include aliases, hosts, ports, usernames, authentication type, key path references, tags, and favorite state. Exported files exclude passwords, private-key passphrases, and Keychain item identifiers.

## Data Model

### Connection Record

Each connection record includes:

- Stable id.
- Alias.
- Host.
- Port.
- Username.
- Authentication type: password or public key.
- Optional private key file path.
- Tags.
- Favorite flag.
- Last connected timestamp.
- Created and updated timestamps.

### History Record

History records are derived from connection attempts and successful sessions. They include host, port, username, alias when available, authentication type, and timestamps. They do not include secrets.

### Credential Record

Credentials are stored in Keychain and referenced by stable connection identity. The app avoids showing, exporting, logging, or serializing credential values.

### Transfer Record

Transfer records include:

- Transfer id.
- Session id.
- Direction: upload or download.
- Local path.
- Remote path.
- Byte progress.
- State.
- Error message if failed.

Transfer records may be kept only for the running app session in version one unless persistent transfer history is explicitly added later.

## Data Flow

### Connect

1. User selects a favorite/history item or creates a manual connection.
2. TermC loads the non-sensitive connection record from `ConnectionStore`.
3. TermC requests the needed credential from `CredentialStore` or prompts the user if missing.
4. `SSHSessionManager` creates a Traversio connection.
5. Host-key trust is checked through `HostKeyTrustStore`.
6. A shell session is opened.
7. `TerminalSessionView` attaches SwiftTerm to the shell IO streams.
8. The tab moves to connected state and history is updated.

### File Transfer

1. User opens the SFTP drawer for the active tab.
2. `SFTPService` starts or reuses an SFTP channel over the active SSH connection.
3. User selects upload or download through native file panels.
4. `TransferQueue` creates a transfer job.
5. `SFTPService` streams file data and reports progress.
6. The drawer updates progress and final state.

### Import and Export

Import reads a user-selected configuration file, validates fields, deduplicates records, and writes non-sensitive data into `ConnectionStore`.

Export writes selected or all connection records to a user-selected file. The export flow clearly omits secrets and should not include Keychain references that would imply credentials are portable.

## Security and Privacy

- Secrets are stored only in Keychain.
- Export files omit secrets.
- Logs must not include passwords, passphrases, private key material, or raw authentication payloads.
- Host-key trust changes require clear user confirmation.
- A changed known host key is treated as a warning state, not a silent reconnect.
- Private key paths may be stored as references, but passphrases are Keychain-only.
- Clipboard paste into terminal should be supported, with optional paste confirmation for multi-line paste as a later enhancement.

## Error Handling

Connection errors should show concise, actionable messages:

- DNS or network failure.
- Authentication failed.
- Missing private key.
- Wrong passphrase.
- Host key unknown.
- Host key changed.
- SFTP unavailable.
- Permission denied for file operations.
- Transfer interrupted.

Disconnected terminal tabs remain visible and offer reconnect. SFTP drawer errors are scoped to the drawer and should not destroy the terminal session unless the underlying SSH connection is closed.

## Keyboard and Commands

The first version should support expected macOS terminal commands:

- New connection.
- New tab.
- Close tab.
- Next and previous tab.
- Toggle left sidebar.
- Toggle SFTP drawer.
- Clear terminal.
- Copy and paste.
- Show or hide main window from menu bar.

Exact shortcuts can be finalized during implementation, but they should follow macOS conventions where possible.

## Testing Strategy

### Unit Tests

- Connection record serialization and migration.
- Import and export validation.
- Keychain wrapper behavior with mocked storage.
- Transfer queue state transitions.
- Host-key trust decisions.

### Integration Tests

- Successful password connection to a controlled SSH test server.
- Successful public-key connection to a controlled SSH test server.
- Authentication failure handling.
- Host-key unknown and host-key changed flows.
- SFTP list, upload, download, delete, and mkdir against a controlled server.

### UI Tests

- Create and save connection.
- Favorite and unfavorite connection.
- Clear history.
- Open multiple tabs.
- Collapse and expand both side panels.
- Open SFTP drawer and start a transfer.
- Hide and restore from menu bar.

### Manual Verification

- Terminal rendering, resizing, paste behavior, and scrollback.
- App icon appearance at standard macOS icon sizes.
- Menu bar white hexagram visibility in light and dark mode.
- Import/export files do not contain secrets.

## Milestones

### Milestone 1: App Foundation

Create the macOS project, app shell, window layout, collapsible side panels, tab UI, static terminal preview, menu bar item, and initial icon assets.

### Milestone 2: Connection Storage and Forms

Implement connection records, history, favorites, clear history, import/export, and Keychain-backed credential storage.

### Milestone 3: SSH Terminal

Integrate SwiftTerm and Traversio shell sessions, support password and key authentication, connect terminal IO, handle resize, disconnect, reconnect, and tab lifecycle.

### Milestone 4: SFTP Drawer

Implement SFTP listing, upload, download, mkdir, delete, refresh, transfer queue, progress, and cancellation.

### Milestone 5: Polish and Verification

Refine macOS keyboard commands, menu bar behavior, empty states, errors, icon assets, accessibility labels, tests, and manual verification.

## Open Constraints

- App Store distribution is not decided. This affects sandboxing, file access, network entitlements, and any use of private APIs.
- Minimum macOS version is not yet fixed. The implementation should choose a version that supports the required SwiftUI and dependency APIs without unnecessary compatibility burden.
- Traversio licensing and packaging should be reviewed before release, even though it is the selected technical direction for this design.

## References

- Traversio: https://traversio.org/
- SwiftTerm: https://github.com/migueldeicaza/SwiftTerm
- SwiftNIO SSH: https://github.com/apple/swift-nio-ssh
