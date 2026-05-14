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

            drawMagicHexagram(
                in: CGRect(
                    x: bounds.width * 0.19,
                    y: bounds.height * 0.19,
                    width: bounds.width * 0.62,
                    height: bounds.height * 0.62
                ),
                color: .white,
                lineWidth: bounds.width * 0.014,
                drawsTerminalPrompt: true
            )
        }
    }

    private static func drawMenuBarTemplate(pixelSize: Int) -> NSBitmapImageRep {
        drawBitmap(pixelWidth: pixelSize, pixelHeight: pixelSize) { _, bounds in
            drawMagicHexagram(
                in: CGRect(x: bounds.width * 0.12, y: bounds.height * 0.12, width: bounds.width * 0.76, height: bounds.height * 0.76),
                color: .white,
                lineWidth: bounds.width * 0.075,
                drawsTerminalPrompt: false
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

    private static func drawTerminalPrompt(in rect: CGRect) {
        let prompt = ">_"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: rect.width * 0.20, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = prompt.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2 - rect.height * 0.015,
            width: textSize.width,
            height: textSize.height
        )
        prompt.draw(in: textRect, withAttributes: attributes)
    }

    private static func drawMagicHexagram(
        in rect: CGRect,
        color: NSColor,
        lineWidth: CGFloat,
        drawsTerminalPrompt: Bool
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let upward = trianglePoints(center: center, radius: radius * 0.86, rotation: -.pi / 2)
        let downward = trianglePoints(center: center, radius: radius * 0.86, rotation: .pi / 2)

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

        context.setLineWidth(lineWidth * 0.55)
        strokeCircle(center: center, radius: radius * 0.67, in: context)
        strokeCircle(center: center, radius: radius * 0.34, in: context)
        drawPortalTicks(center: center, radius: radius, color: color, lineWidth: lineWidth * 0.55, in: context)
        drawPortalNodes(center: center, radius: radius * 0.67, color: color, lineWidth: lineWidth, in: context)

        context.restoreGState()

        if drawsTerminalPrompt {
            drawTerminalPrompt(in: rect)
        }
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

    private static func strokeCircle(center: CGPoint, radius: CGFloat, in context: CGContext) {
        context.strokeEllipse(
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }

    private static func drawPortalTicks(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)

        for index in 0..<24 {
            let angle = CGFloat(index) * 2 * .pi / 24
            let isMajorTick = index % 4 == 0
            let outer = point(center: center, radius: radius * 0.98, angle: angle)
            let inner = point(center: center, radius: radius * (isMajorTick ? 0.88 : 0.92), angle: angle)
            context.beginPath()
            context.move(to: outer)
            context.addLine(to: inner)
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func drawPortalNodes(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(color.cgColor)

        for index in 0..<6 {
            let angle = -.pi / 2 + CGFloat(index) * 2 * .pi / 6
            let nodeCenter = point(center: center, radius: radius, angle: angle)
            let nodeRadius = lineWidth * 1.55
            context.fillEllipse(
                in: CGRect(
                    x: nodeCenter.x - nodeRadius,
                    y: nodeCenter.y - nodeRadius,
                    width: nodeRadius * 2,
                    height: nodeRadius * 2
                )
            )
        }

        context.restoreGState()
    }

    private static func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    private static func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}
