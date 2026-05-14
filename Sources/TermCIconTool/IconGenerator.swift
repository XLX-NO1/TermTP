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
                    x: bounds.width * 0.16,
                    y: bounds.height * 0.16,
                    width: bounds.width * 0.68,
                    height: bounds.height * 0.68
                ),
                color: .white,
                lineWidth: bounds.width * 0.011,
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
            .font: NSFont.monospacedSystemFont(ofSize: rect.width * 0.23, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = prompt.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2 - rect.height * 0.018,
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
        let upward = trianglePoints(center: center, radius: radius * 0.70, rotation: -.pi / 2)
        let downward = trianglePoints(center: center, radius: radius * 0.70, rotation: .pi / 2)

        let outerCircle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        drawFlowingRibbons(center: center, radius: radius, color: color, lineWidth: lineWidth)

        context.saveGState()
        context.setShouldAntialias(true)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: lineWidth * 6.0,
            color: color.withAlphaComponent(0.44).cgColor
        )
        context.setStrokeColor(color.withAlphaComponent(0.24).cgColor)
        context.setLineWidth(lineWidth * 2.4)
        context.strokeEllipse(in: outerCircle)
        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)
        strokeCircle(center: center, radius: radius * 0.78, in: context)
        strokeCircle(center: center, radius: radius * 0.55, in: context)
        strokeCircle(center: center, radius: radius * 0.30, in: context)
        drawPortalTicks(center: center, radius: radius, color: color.withAlphaComponent(0.38), lineWidth: lineWidth * 1.2, count: 48, in: context)
        drawStarMedallions(center: center, radius: radius * 0.82, color: color.withAlphaComponent(0.34), lineWidth: lineWidth * 1.15, in: context)
        context.restoreGState()

        context.saveGState()
        context.setShouldAntialias(true)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth * 2.4)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.strokeEllipse(in: outerCircle)

        context.setLineWidth(lineWidth * 1.35)
        strokePolygon(upward, in: context)
        strokePolygon(downward, in: context)
        drawTriangleOverlays(center: center, radius: radius, color: color.withAlphaComponent(0.88), lineWidth: lineWidth * 0.58, in: context)

        context.setLineWidth(lineWidth * 0.72)
        context.setStrokeColor(color.withAlphaComponent(0.80).cgColor)
        strokeCircle(center: center, radius: radius * 0.78, in: context)
        context.setStrokeColor(color.withAlphaComponent(0.52).cgColor)
        strokeCircle(center: center, radius: radius * 0.55, in: context)
        context.setStrokeColor(color.withAlphaComponent(0.92).cgColor)
        strokeCircle(center: center, radius: radius * 0.30, in: context)
        drawPortalTicks(center: center, radius: radius, color: color.withAlphaComponent(0.88), lineWidth: lineWidth * 0.48, count: 48, in: context)
        drawStarMedallions(center: center, radius: radius * 0.82, color: color, lineWidth: lineWidth * 0.70, in: context)
        drawSmallStars(center: center, radius: radius * 0.61, color: color.withAlphaComponent(0.85), in: context)

        context.restoreGState()

        if drawsTerminalPrompt {
            drawTerminalPrompt(
                in: rect,
                color: NSColor(calibratedRed: 0.25, green: 0.94, blue: 0.48, alpha: 1)
            )
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
        count: Int = 24,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)

        for index in 0..<count {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(count)
            let isMajorTick = index % 6 == 0
            let outer = point(center: center, radius: radius * 0.98, angle: angle)
            let inner = point(center: center, radius: radius * (isMajorTick ? 0.88 : 0.92), angle: angle)
            context.beginPath()
            context.move(to: outer)
            context.addLine(to: inner)
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func drawStarMedallions(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.withAlphaComponent(0.92).cgColor)
        context.setLineWidth(lineWidth)

        for index in 0..<4 {
            let angle = -.pi / 2 + CGFloat(index) * .pi / 2
            let medallionCenter = point(center: center, radius: radius, angle: angle)
            let medallionRadius = lineWidth * 3.0
            strokeCircle(center: medallionCenter, radius: medallionRadius, in: context)
            drawStar(center: medallionCenter, radius: medallionRadius * 0.58, color: color, in: context)
        }

        context.restoreGState()
    }

    private static func drawStar(center: CGPoint, radius: CGFloat, color: NSColor, in context: CGContext) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.beginPath()
        for index in 0..<10 {
            let angle = -.pi / 2 + CGFloat(index) * .pi / 5
            let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.42
            let starPoint = point(center: center, radius: pointRadius, angle: angle)
            if index == 0 {
                context.move(to: starPoint)
            } else {
                context.addLine(to: starPoint)
            }
        }
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    private static func drawTriangleOverlays(
        center: CGPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)

        let left = point(center: center, radius: radius * 0.60, angle: .pi)
        let right = point(center: center, radius: radius * 0.60, angle: 0)
        let top = point(center: center, radius: radius * 0.64, angle: -.pi / 2)
        let bottom = point(center: center, radius: radius * 0.64, angle: .pi / 2)

        context.beginPath()
        context.move(to: left)
        context.addLine(to: top)
        context.addLine(to: right)
        context.move(to: left)
        context.addLine(to: bottom)
        context.addLine(to: right)
        context.strokePath()

        context.restoreGState()
    }

    private static func drawSmallStars(center: CGPoint, radius: CGFloat, color: NSColor, in context: CGContext) {
        context.saveGState()
        context.setFillColor(color.cgColor)

        for index in 0..<8 {
            let angle = CGFloat(index) * 2 * .pi / 8 + .pi / 8
            let starCenter = point(center: center, radius: radius, angle: angle)
            drawStar(center: starCenter, radius: radius * 0.028, color: color, in: context)
        }

        context.restoreGState()
    }

    private static func drawFlowingRibbons(center: CGPoint, radius: CGFloat, color: NSColor, lineWidth: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.setStrokeColor(color.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(lineWidth * 0.58)
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: lineWidth * 2.6,
            color: color.withAlphaComponent(0.14).cgColor
        )

        for index in 0..<2 {
            let verticalOffset = CGFloat(index == 0 ? -1 : 1) * radius * 0.16
            context.beginPath()
            context.move(to: CGPoint(x: center.x - radius * 1.05, y: center.y + verticalOffset))
            context.addCurve(
                to: CGPoint(x: center.x + radius * 1.05, y: center.y - verticalOffset * 0.7),
                control1: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.45 + verticalOffset),
                control2: CGPoint(x: center.x + radius * 0.35, y: center.y + radius * 0.45 - verticalOffset)
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
