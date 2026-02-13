#!/usr/bin/env swift

import AppKit
import Foundation

// macOS icon sizes: (pointSize, scale, pixelSize)
let iconSizes: [(String, Int, Int)] = [
    ("icon_16x16",     16,  1),
    ("icon_16x16@2x",  16,  2),
    ("icon_32x32",     32,  1),
    ("icon_32x32@2x",  32,  2),
    ("icon_128x128",   128, 1),
    ("icon_128x128@2x",128, 2),
    ("icon_256x256",   256, 1),
    ("icon_256x256@2x",256, 2),
    ("icon_512x512",   512, 1),
    ("icon_512x512@2x",512, 2),
]

let accentColor = NSColor(red: 240.0/255, green: 185.0/255, blue: 11.0/255, alpha: 1.0)
let iconColor = NSColor.white

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // macOS icon corner radius is ~22.37% of size (Apple's standard squircle approximation)
    let cornerRadius = size * 0.2237

    // Draw rounded rectangle background
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    accentColor.setFill()
    path.fill()

    // Draw the audio-waveform icon
    // Original lucide SVG viewBox: 0 0 24 24, stroke-width: 2
    // Path: M2 13a2 2 0 0 0 2-2V7a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0V4a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0v-4a2 2 0 0 1 2-2
    //
    // We scale the 24x24 icon to occupy ~50% of the icon size, centered
    let iconSize = size * 0.50
    let scale = iconSize / 24.0
    let strokeWidth = 2.0 * scale
    let offsetX = (size - iconSize) / 2.0
    let offsetY = (size - iconSize) / 2.0

    context.saveGState()

    // Flip coordinate system (SVG is top-left origin, CoreGraphics is bottom-left)
    context.translateBy(x: offsetX, y: offsetY + iconSize)
    context.scaleBy(x: scale, y: -scale)

    // Build the waveform path using CGPath
    let waveform = CGMutablePath()

    // M2 13
    waveform.move(to: CGPoint(x: 2, y: 13))

    // a2 2 0 0 0 2 -2 -> arc to (4, 11)
    // This is a small arc curving right-upward
    waveform.addQuadCurve(to: CGPoint(x: 4, y: 11), control: CGPoint(x: 2, y: 11))

    // V7 -> line to (4, 7)
    waveform.addLine(to: CGPoint(x: 4, y: 7))

    // a2 2 0 0 1 4 0 -> arc to (8, 7), curving down
    waveform.addQuadCurve(to: CGPoint(x: 8, y: 7), control: CGPoint(x: 6, y: 4.5))

    // v13 -> line to (8, 20)
    waveform.addLine(to: CGPoint(x: 8, y: 20))

    // a2 2 0 0 0 4 0 -> arc to (12, 20), curving down
    waveform.addQuadCurve(to: CGPoint(x: 12, y: 20), control: CGPoint(x: 10, y: 22.5))

    // V4 -> line to (12, 4)
    waveform.addLine(to: CGPoint(x: 12, y: 4))

    // a2 2 0 0 1 4 0 -> arc to (16, 4), curving down (actually up since y is small)
    waveform.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: 14, y: 1.5))

    // v13 -> line to (16, 17)
    waveform.addLine(to: CGPoint(x: 16, y: 17))

    // a2 2 0 0 0 4 0 -> arc to (20, 17), curving down
    waveform.addQuadCurve(to: CGPoint(x: 20, y: 17), control: CGPoint(x: 18, y: 19.5))

    // v-4 -> line to (20, 13)
    waveform.addLine(to: CGPoint(x: 20, y: 13))

    // a2 2 0 0 1 2 -2 -> arc to (22, 11)
    waveform.addQuadCurve(to: CGPoint(x: 22, y: 11), control: CGPoint(x: 22, y: 13))

    context.setStrokeColor(iconColor.cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(waveform)
    context.strokePath()

    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, pixelSize: Int, to path: String) {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    image.draw(in: NSRect(origin: .zero, size: size),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: path))
}

// Main
let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

print("Generating macOS app icons to: \(outputDir)")

for (name, pointSize, scale) in iconSizes {
    let pixelSize = pointSize * scale
    let image = drawIcon(size: CGFloat(pixelSize))
    let filename = "\(name).png"
    let path = (outputDir as NSString).appendingPathComponent(filename)
    savePNG(image: image, pixelSize: pixelSize, to: path)
    print("  Generated \(filename) (\(pixelSize)x\(pixelSize)px)")
}

print("Done! All icons generated.")
