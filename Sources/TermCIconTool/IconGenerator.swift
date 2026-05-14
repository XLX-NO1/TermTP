import AppKit
import CoreGraphics
import Foundation

enum IconGenerator {
    static func generateAll(in outputDirectory: URL) throws {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let appIcon = drawAppIcon(pixelSize: 1024)
        let menuBarIcon = drawMenuBarTemplate(pixelSize: 64)

        try writePNG(appIcon, to: outputDirectory.appendingPathComponent("TermTPIcon-1024.png"))
        try writePNG(menuBarIcon, to: outputDirectory.appendingPathComponent("TermTPMenuBarTemplate.png"))
    }

    private static func drawAppIcon(pixelSize: Int) -> NSBitmapImageRep {
        drawBitmap(pixelWidth: pixelSize, pixelHeight: pixelSize) { context, bounds in

            context.setShouldAntialias(true)
            let cornerRadius = bounds.width * 0.19
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
                in: CGRect(
                    x: bounds.width * 0.42,
                    y: bounds.height * 0.43,
                    width: bounds.width * 0.36,
                    height: bounds.height * 0.36
                ),
                color: .white,
                lineWidth: bounds.width * 0.017
            )
        }
    }

    private static func drawMenuBarTemplate(pixelSize: Int) -> NSBitmapImageRep {
        drawBitmap(pixelWidth: pixelSize, pixelHeight: pixelSize) { _, bounds in
            drawHexagram(
                in: CGRect(x: bounds.width * 0.12, y: bounds.height * 0.12, width: bounds.width * 0.76, height: bounds.height * 0.76),
                color: .white,
                lineWidth: bounds.width * 0.085
            )
        }
    }

    private static func drawBitmap(
        pixelWidth: Int,
        pixelHeight: Int,
        draw: (CGContext, CGRect) -> Void
    ) -> NSBitmapImageRep {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            preconditionFailure("Unable to create bitmap context for icon generation")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let context = graphicsContext.cgContext
        let bounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        context.clear(bounds)
        draw(context, bounds)

        return bitmap
    }

    private static func drawTerminalPrompt(in bounds: CGRect) {
        let prompt = ">_"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: bounds.width * 0.31, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = prompt.size(withAttributes: attributes)
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2 - bounds.width * 0.10,
            y: bounds.midY - textSize.height / 2 - bounds.height * 0.06,
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

        let outerCircle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.strokeEllipse(in: outerCircle)
        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)

        let centerDotRadius = radius * 0.13
        context.setFillColor(color.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: center.x - centerDotRadius,
                y: center.y - centerDotRadius,
                width: centerDotRadius * 2,
                height: centerDotRadius * 2
            )
        )

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

    private static func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}
