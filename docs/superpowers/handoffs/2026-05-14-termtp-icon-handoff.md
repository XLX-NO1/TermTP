# TermTP Icon Handoff

Date: 2026-05-14

## Current State

Work is in:

```text
/Users/suweichao/ssh终端工具/.worktrees/termc-implementation
```

Branch:

```text
termc-implementation
```

Latest commit before this handoff:

```text
4e617eb fix: keep icon monochrome with anime sigil geometry
```

The worktree was clean before writing this handoff.

## Product Rename

The app has officially been renamed from `TermC` to `TermTP`.

Important rename commit:

```text
ef8faff feat: rename app to TermTP
```

User-facing names, bundle output, bundle id, icon resource names, welcome text, fake SSH greeting, and Keychain service were updated. SwiftPM package, target, module, and some internal type names still use `TermC` / `TermCCore` / `TermCApp` to avoid large structural churn. Do not assume those internal names are user-facing.

Current bundle output is:

```text
build/TermTP.app
```

## Recent Icon Work

The icon generator is:

```text
Sources/TermCIconTool/IconGenerator.swift
```

Generated app icon:

```text
build/icons/TermTPIcon-1024.png
```

Generated menu bar template icon:

```text
build/icons/TermTPMenuBarTemplate.png
```

Recent icon commits:

```text
553712b fix: refine TermTP icon mark
0d559f5 fix: make icon a magic terminal sigil
582cc0c fix: restyle icon with anime magic glow
4e617eb fix: keep icon monochrome with anime sigil geometry
```

The user clarified that they did not want a colorful anime palette. They want the icon to stay monochrome / white like the earlier version, but the geometry should feel more like a Japanese anime magic circle.

## Reference Image

The user added a reference image at:

```text
/Users/suweichao/ssh终端工具/IMG_20260514_100127.png
```

Use this reference for geometry, not color. Key visual ideas from the reference:

- dark background;
- bright white magic circle;
- thick outer ring;
- dense short tick marks inside the ring;
- central six-point/star geometry;
- concentric inner rings;
- simple star medallions at cardinal points;
- diagonal triangle overlays;
- sparse star dust and a few flowing ribbon-like strokes.

The user now asks to design a simpler app icon based on that reference. Recommended direction:

- Keep the background dark terminal-style.
- Keep the magic circle and terminal symbol white.
- Simplify the current geometry rather than adding more clutter.
- Use a bold outer ring, one tick ring, a centered six-point structure, a central `>_`, and 3-4 small star medallions.
- Add only subtle star dust or ribbon arcs if they still read at Dock-icon sizes.
- Keep the menu bar icon a clean white template. Avoid tiny details there.

## Current Icon State

The current icon is monochrome and functional, but it is a bit visually busy. It has:

- white six-point geometry;
- multiple concentric circles;
- portal ticks;
- circular and diamond nodes;
- rune marks;
- arc segments;
- center `>_` terminal prompt.

The next pass should make it cleaner and closer to the reference image by prioritizing large readable forms.

## Verification Commands

After icon edits, run:

```bash
scripts/generate-icons.sh
scripts/build-app.sh
swift test
test -f build/icons/TermTPIcon-1024.png
test -f build/icons/TermTPMenuBarTemplate.png
test -d build/TermTP.app
test -f build/TermTP.app/Contents/MacOS/TermTP
```

Show the generated icon preview from:

```text
/Users/suweichao/ssh终端工具/.worktrees/termc-implementation/build/icons/TermTPIcon-1024.png
```

## Notes For Next Agent

- Respond in Chinese.
- The user wants iterative visual work and often refines the icon after seeing a preview.
- Do not reintroduce cyan/pink colors unless the user explicitly asks for color.
- Do not rename SwiftPM modules unless explicitly requested.
- Prefer scoped edits in `Sources/TermCIconTool/IconGenerator.swift`.
- If committing, keep icon iterations in their own commits.
