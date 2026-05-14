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

            drawSparkles(in: bounds)

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

    private static func drawSparkles(in bounds: CGRect) {
        let sparkles: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.25, 0.26, 0.017, 0.70),
            (0.74, 0.28, 0.011, 0.55),
            (0.24, 0.74, 0.010, 0.45),
            (0.77, 0.70, 0.015, 0.65),
            (0.50, 0.83, 0.009, 0.42)
        ]

        for sparkle in sparkles {
            drawSparkle(
                center: CGPoint(x: bounds.width * sparkle.0, y: bounds.height * sparkle.1),
                radius: bounds.width * sparkle.2,
                alpha: sparkle.3
            )
        }
    }

    private static func drawSparkle(center: CGPoint, radius: CGFloat, alpha: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: alpha).cgColor)
        context.setLineWidth(radius * 0.22)
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: radius * 1.6,
            color: NSColor(calibratedWhite: 1, alpha: alpha * 0.5).cgColor
        )
        context.beginPath()
        context.move(to: CGPoint(x: center.x - radius, y: center.y))
        context.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - radius))
        context.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawTerminalPrompt(in rect: CGRect, color: NSColor) {
        let prompt = ">_"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: rect.width * 0.20, weight: .bold),
            .foregroundColor: color,
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

        let outerCircle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.saveGState()
        context.setShouldAntialias(true)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: lineWidth * 5.5,
            color: color.withAlphaComponent(0.50).cgColor
        )
        context.setStrokeColor(color.withAlphaComponent(0.28).cgColor)
        context.setLineWidth(lineWidth * 2.6)
        context.strokeEllipse(in: outerCircle)
        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)
        strokeCircle(center: center, radius: radius * 0.67, in: context)
        strokeCircle(center: center, radius: radius * 0.50, in: context)
        strokeCircle(center: center, radius: radius * 0.34, in: context)
        drawPortalTicks(center: center, radius: radius, color: color.withAlphaComponent(0.46), lineWidth: lineWidth * 1.4, in: context)
        drawPortalDiamonds(center: center, radius: radius * 0.74, color: color.withAlphaComponent(0.38), size: lineWidth * 3.1, in: context)
        drawRuneMarks(center: center, radius: radius * 0.58, color: color.withAlphaComponent(0.36), lineWidth: lineWidth * 1.1, in: context)
        context.restoreGState()

        context.saveGState()
        context.setShouldAntialias(true)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.strokeEllipse(in: outerCircle)
        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)
        drawArcaneArcs(center: center, radius: radius * 0.78, color: color.withAlphaComponent(0.92), lineWidth: lineWidth * 0.52, in: context)

        context.setLineWidth(lineWidth * 0.55)
        context.setStrokeColor(color.withAlphaComponent(0.80).cgColor)
        strokeCircle(center: center, radius: radius * 0.67, in: context)
        context.setStrokeColor(color.withAlphaComponent(0.55).cgColor)
        strokeCircle(center: center, radius: radius * 0.50, in: context)
        context.setStrokeColor(color.withAlphaComponent(0.92).cgColor)
        strokeCircle(center: center, radius: radius * 0.34, in: context)
        drawPortalTicks(center: center, radius: radius, color: color.withAlphaComponent(0.85), lineWidth: lineWidth * 0.55, in: context)
        drawPortalNodes(center: center, radius: radius * 0.67, color: color, lineWidth: lineWidth, in: context)
        drawPortalDiamonds(center: center, radius: radius * 0.74, color: color, size: lineWidth * 2.2, in: context)
        drawRuneMarks(center: center, radius: radius * 0.58, color: color.withAlphaComponent(0.82), lineWidth: lineWidth * 0.52, in: context)

        context.restoreGState()

        if drawsTerminalPrompt {
            drawTerminalPrompt(in: rect, color: color)
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

    private static func drawPortalDiamonds(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        size: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(color.cgColor)

        for index in 0..<6 {
            let angle = CGFloat(index) * 2 * .pi / 6
            let diamondCenter = point(center: center, radius: radius, angle: angle)
            context.beginPath()
            context.move(to: CGPoint(x: diamondCenter.x, y: diamondCenter.y - size))
            context.addLine(to: CGPoint(x: diamondCenter.x + size, y: diamondCenter.y))
            context.addLine(to: CGPoint(x: diamondCenter.x, y: diamondCenter.y + size))
            context.addLine(to: CGPoint(x: diamondCenter.x - size, y: diamondCenter.y))
            context.closePath()
            context.fillPath()
        }

        context.restoreGState()
    }

    private static func drawRuneMarks(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)

        for index in 0..<12 {
            let angle = CGFloat(index) * 2 * .pi / 12
            let markCenter = point(center: center, radius: radius, angle: angle)
            let tangent = angle + .pi / 2
            let halfLength = radius * (index % 3 == 0 ? 0.038 : 0.025)
            context.beginPath()
            context.move(to: point(center: markCenter, radius: halfLength, angle: tangent))
            context.addLine(to: point(center: markCenter, radius: halfLength, angle: tangent + .pi))
            if index % 4 == 1 {
                context.move(to: markCenter)
                context.addLine(to: point(center: markCenter, radius: halfLength * 0.85, angle: angle))
            }
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func drawArcaneArcs(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)

        for index in 0..<6 {
            let start = CGFloat(index) * 2 * .pi / 6 + .pi / 18
            let end = start + .pi / 7
            context.beginPath()
            context.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: false
            )
            context.strokePath()
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
