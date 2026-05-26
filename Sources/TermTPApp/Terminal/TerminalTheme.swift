import AppKit
import Foundation

enum TerminalTheme: String, CaseIterable, Identifiable, Sendable {
    case classicGreen
    case amber
    case paperWhite
    case ocean

    static let `default`: TerminalTheme = .classicGreen

    var id: String { rawValue }
}

struct TerminalPalette: Equatable, Sendable {
    var background: TerminalColor
    var foreground: TerminalColor
    var caret: TerminalColor

    static func palette(for theme: TerminalTheme) -> TerminalPalette {
        switch theme {
        case .classicGreen:
            return TerminalPalette(
                background: TerminalColor(red: 0.0, green: 0.0, blue: 0.0),
                foreground: TerminalColor(red: 0.45, green: 1.0, blue: 0.55),
                caret: TerminalColor(red: 0.45, green: 1.0, blue: 0.55)
            )
        case .amber:
            return TerminalPalette(
                background: TerminalColor(red: 0.06, green: 0.045, blue: 0.02),
                foreground: TerminalColor(red: 1.0, green: 0.66, blue: 0.18),
                caret: TerminalColor(red: 1.0, green: 0.66, blue: 0.18)
            )
        case .paperWhite:
            return TerminalPalette(
                background: TerminalColor(red: 0.95, green: 0.95, blue: 0.91),
                foreground: TerminalColor(red: 0.08, green: 0.09, blue: 0.10),
                caret: TerminalColor(red: 0.08, green: 0.09, blue: 0.10)
            )
        case .ocean:
            return TerminalPalette(
                background: TerminalColor(red: 0.02, green: 0.08, blue: 0.12),
                foreground: TerminalColor(red: 0.50, green: 0.92, blue: 1.0),
                caret: TerminalColor(red: 0.50, green: 0.92, blue: 1.0)
            )
        }
    }
}

struct TerminalColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}
