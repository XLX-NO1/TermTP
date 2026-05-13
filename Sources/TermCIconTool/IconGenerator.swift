import AppKit
import CoreGraphics
import Foundation

enum IconGenerator {
    static func generateAll(in outputDirectory: URL) throws {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let appIcon = drawAppIcon(size: CGSize(width: 1024, height: 1024))
        let menuBarIcon = drawMenuBarTemplate(size: CGSize(width: 64, height: 64))

        try writePNG(appIcon, to: outputDirectory.appendingPathComponent("TermCIcon-1024.png"))
        try writePNG(menuBarIcon, to: outputDirectory.appendingPathComponent("TermCMenuBarTemplate.png"))
    }

    private static func drawAppIcon(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return image
        }

        context.setShouldAntialias(true)
        let bounds = CGRect(origin: .zero, size: size)
        let cornerRadius = size.width * 0.19
        let roundedRect = CGPath(
            roundedRect: bounds.insetBy(dx: 24, dy: 24),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        context.saveGState()
        context.addPath(roundedRect)
        context.clip()

        let background = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.05, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.13, alpha: 1).cgColor
            ] as CFArray,
            locations: [0, 1]
        )
        if let background {
            context.drawLinearGradient(
                background,
                start: CGPoint(x: bounds.minX, y: bounds.maxY),
                end: CGPoint(x: bounds.maxX, y: bounds.minY),
                options: []
            )
        }

        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.08).cgColor)
        context.setLineWidth(8)
        context.addPath(roundedRect)
        context.strokePath()
        context.restoreGState()

        drawTerminalPrompt(in: bounds)
        drawHexagram(
            in: CGRect(x: size.width * 0.62, y: size.height * 0.60, width: size.width * 0.22, height: size.height * 0.22),
            color: .white,
            lineWidth: size.width * 0.018
        )

        return image
    }

    private static func drawMenuBarTemplate(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        drawHexagram(
            in: CGRect(x: size.width * 0.12, y: size.height * 0.12, width: size.width * 0.76, height: size.height * 0.76),
            color: .white,
            lineWidth: size.width * 0.085
        )

        image.isTemplate = true
        return image
    }

    private static func drawTerminalPrompt(in bounds: CGRect) {
        let prompt = ">_"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: bounds.width * 0.31, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.25, green: 0.94, blue: 0.48, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]

        let textSize = prompt.size(withAttributes: attributes)
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 - bounds.height * 0.03,
            width: textSize.width,
            height: textSize.height
        )
        prompt.draw(in: textRect, withAttributes: attributes)
    }

    private static func drawHexagram(in rect: CGRect, color: NSColor, lineWidth: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let upward = trianglePoints(center: center, radius: radius, rotation: -.pi / 2)
        let downward = trianglePoints(center: center, radius: radius, rotation: .pi / 2)

        context.saveGState()
        context.setShouldAntialias(true)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)

        context.restoreGState()
    }

    private static func trianglePoints(center: CGPoint, radius: CGFloat, rotation: CGFloat) -> [CGPoint] {
        (0..<3).map { index in
            let angle = rotation + CGFloat(index) * 2 * .pi / 3
            return CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
    }

    private static func strokePolygon(_ points: [CGPoint], in context: CGContext) {
        guard let first = points.first else {
            return
        }

        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.closePath()
        context.strokePath()
    }

    private static func writePNG(_ image: NSImage, to url: URL) throws {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}
