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

            let iconRect = bounds.insetBy(dx: bounds.width * 0.035, dy: bounds.height * 0.035)
            let iconPath = CGPath(
                roundedRect: iconRect,
                cornerWidth: bounds.width * 0.205,
                cornerHeight: bounds.width * 0.205,
                transform: nil
            )

            drawOuterShadow(for: iconPath, in: context)

            context.saveGState()
            context.addPath(iconPath)
            context.clip()
            drawBackground(in: iconRect, context: context)
            drawCornerGlow(in: iconRect, context: context)
            drawTerminalPanel(in: iconRect, context: context)
            context.restoreGState()

            context.saveGState()
            context.addPath(iconPath)
            context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.11).cgColor)
            context.setLineWidth(bounds.width * 0.010)
            context.strokePath()
            context.restoreGState()
        }
    }

    private static func drawMenuBarTemplate(pixelSize: Int) -> NSBitmapImageRep {
        drawBitmap(pixelWidth: pixelSize, pixelHeight: pixelSize) { context, bounds in
            context.setShouldAntialias(true)
            drawPromptMark(
                in: bounds.insetBy(dx: bounds.width * 0.14, dy: bounds.height * 0.19),
                color: .white,
                lineWidth: bounds.width * 0.095,
                glow: nil,
                context: context
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

    private static func drawOuterShadow(for path: CGPath, in context: CGContext) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -18),
            blur: 34,
            color: NSColor(calibratedWhite: 0, alpha: 0.30).cgColor
        )
        context.addPath(path)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawBackground(in rect: CGRect, context: CGContext) {
        let background = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.015, green: 0.018, blue: 0.020, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.036, green: 0.065, blue: 0.053, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.010, green: 0.015, blue: 0.016, alpha: 1).cgColor
            ] as CFArray,
            locations: [0.0, 0.55, 1.0]
        )

        if let background {
            context.drawLinearGradient(
                background,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )
        }

        context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.035).cgColor)
        context.fill(
            CGRect(
                x: rect.minX,
                y: rect.maxY - rect.height * 0.30,
                width: rect.width,
                height: rect.height * 0.30
            )
        )
    }

    private static func drawCornerGlow(in rect: CGRect, context: CGContext) {
        let glow = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedRed: 0.21, green: 0.96, blue: 0.47, alpha: 0.45).cgColor,
                NSColor(calibratedRed: 0.11, green: 0.60, blue: 0.30, alpha: 0.12).cgColor,
                NSColor(calibratedRed: 0.11, green: 0.60, blue: 0.30, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0.0, 0.42, 1.0]
        )

        guard let glow else {
            return
        }

        context.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.minY + rect.height * 0.26),
            startRadius: 0,
            endCenter: CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.minY + rect.height * 0.26),
            endRadius: rect.width * 0.54,
            options: [.drawsAfterEndLocation]
        )
    }

    private static func drawTerminalPanel(in rect: CGRect, context: CGContext) {
        let panel = CGRect(
            x: rect.minX + rect.width * 0.165,
            y: rect.minY + rect.height * 0.265,
            width: rect.width * 0.67,
            height: rect.height * 0.47
        )
        let panelPath = CGPath(
            roundedRect: panel,
            cornerWidth: rect.width * 0.070,
            cornerHeight: rect.width * 0.070,
            transform: nil
        )

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -8),
            blur: rect.width * 0.055,
            color: NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.45).cgColor
        )
        context.addPath(panelPath)
        context.setFillColor(NSColor(calibratedRed: 0.018, green: 0.023, blue: 0.024, alpha: 0.96).cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(panelPath)
        context.setStrokeColor(NSColor(calibratedRed: 0.22, green: 0.95, blue: 0.48, alpha: 0.56).cgColor)
        context.setLineWidth(rect.width * 0.009)
        context.strokePath()
        context.restoreGState()

        drawWindowDots(in: panel, context: context)

        let promptRect = CGRect(
            x: panel.minX + panel.width * 0.18,
            y: panel.minY + panel.height * 0.28,
            width: panel.width * 0.64,
            height: panel.height * 0.46
        )
        drawPromptMark(
            in: promptRect,
            color: .white,
            lineWidth: rect.width * 0.043,
            glow: NSColor(calibratedRed: 0.22, green: 1.0, blue: 0.50, alpha: 0.32),
            context: context
        )
    }

    private static func drawWindowDots(in panel: CGRect, context: CGContext) {
        let dotRadius = panel.width * 0.027
        let y = panel.maxY - panel.height * 0.18
        let colors = [
            NSColor(calibratedRed: 0.24, green: 0.92, blue: 0.45, alpha: 0.62),
            NSColor(calibratedWhite: 1, alpha: 0.28),
            NSColor(calibratedWhite: 1, alpha: 0.18)
        ]

        for index in 0..<3 {
            let center = CGPoint(
                x: panel.minX + panel.width * 0.12 + CGFloat(index) * dotRadius * 2.65,
                y: y
            )
            context.setFillColor(colors[index].cgColor)
            context.fillEllipse(
                in: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
            )
        }
    }

    private static func drawPromptMark(
        in rect: CGRect,
        color: NSColor,
        lineWidth: CGFloat,
        glow: NSColor?,
        context: CGContext
    ) {
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(color.cgColor)
        if let glow {
            context.setShadow(offset: .zero, blur: lineWidth * 2.1, color: glow.cgColor)
        }

        let leftX = rect.minX + rect.width * 0.08
        let pointX = rect.minX + rect.width * 0.40
        let topY = rect.maxY - rect.height * 0.16
        let midY = rect.midY + rect.height * 0.02
        let bottomY = rect.minY + rect.height * 0.18

        context.beginPath()
        context.move(to: CGPoint(x: leftX, y: topY))
        context.addLine(to: CGPoint(x: pointX, y: midY))
        context.addLine(to: CGPoint(x: leftX, y: bottomY))
        context.strokePath()

        context.beginPath()
        context.move(to: CGPoint(x: rect.minX + rect.width * 0.54, y: bottomY))
        context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: bottomY))
        context.strokePath()

        context.restoreGState()
    }

    private static func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}
