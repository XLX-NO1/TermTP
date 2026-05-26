import AppKit

enum TerminalFont {
    static let sizeOptions = Array(8...12)
    private static let pointSizeStep: CGFloat = 2

    static func make(size: Int) -> NSFont {
        let pointSize = pointSize(for: size)
        return NSFont.userFixedPitchFont(ofSize: pointSize)
            ?? NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
    }

    static func pointSize(for size: Int) -> CGFloat {
        let minimum = sizeOptions.first ?? size
        let maximum = sizeOptions.last ?? size
        let clampedSize = min(max(size, minimum), maximum)
        return CGFloat(minimum) + CGFloat(clampedSize - minimum) * pointSizeStep
    }

    static func cellMetrics(for size: Int, scale: CGFloat) -> CGSize {
        let font = make(size: size)
        let glyph = font.glyph(withName: "W")
        let width = font.advancement(forGlyph: glyph).width
        let height = ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))

        return CGSize(
            width: ceil(width * scale) / scale,
            height: ceil(height * scale) / scale
        )
    }
}
