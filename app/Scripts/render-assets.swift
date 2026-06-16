#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let scriptsDir = scriptURL.deletingLastPathComponent()
let appDir = scriptsDir.deletingLastPathComponent()
let buildAssetsDir = appDir.appendingPathComponent(".build/assets", isDirectory: true)
let iconsetDir = buildAssetsDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func savePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GlobeAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to render PNG"])
    }
    try data.write(to: url)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024

    context.setFillColor(NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.15, alpha: 1).cgColor)
    context.fill(rect)

    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 74 * scale, dy: 74 * scale), xRadius: 210 * scale, yRadius: 210 * scale)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 0.72, green: 0.86, blue: 1.0, alpha: 1)
    ])
    gradient?.draw(in: bgPath, angle: 135)

    context.saveGState()
    bgPath.addClip()
    context.setFillColor(NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.92, alpha: 0.18).cgColor)
    context.fillEllipse(in: CGRect(x: 590 * scale, y: 560 * scale, width: 390 * scale, height: 390 * scale))
    context.setFillColor(NSColor(calibratedRed: 0.01, green: 0.54, blue: 0.42, alpha: 0.18).cgColor)
    context.fillEllipse(in: CGRect(x: 50 * scale, y: 80 * scale, width: 430 * scale, height: 430 * scale))
    context.restoreGState()

    let keyRect = CGRect(x: 190 * scale, y: 225 * scale, width: 644 * scale, height: 574 * scale)
    let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: 156 * scale, yRadius: 156 * scale)
    context.setShadow(offset: CGSize(width: 0, height: -22 * scale), blur: 36 * scale, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    NSColor.white.setFill()
    keyPath.fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    NSColor(calibratedRed: 0.77, green: 0.81, blue: 0.86, alpha: 1).setStroke()
    keyPath.lineWidth = 3 * scale
    keyPath.stroke()

    let capRect = CGRect(x: 302 * scale, y: 324 * scale, width: 420 * scale, height: 330 * scale)
    let capPath = NSBezierPath(roundedRect: capRect, xRadius: 72 * scale, yRadius: 72 * scale)
    NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 1).setFill()
    capPath.fill()
    NSColor(calibratedRed: 0.62, green: 0.68, blue: 0.74, alpha: 1).setStroke()
    capPath.lineWidth = 4 * scale
    capPath.stroke()

    let globeCenter = CGPoint(x: 512 * scale, y: 488 * scale)
    let globeRadius = 98 * scale
    let globeRect = CGRect(x: globeCenter.x - globeRadius, y: globeCenter.y - globeRadius, width: globeRadius * 2, height: globeRadius * 2)
    NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.13, alpha: 1).setStroke()
    let globePath = NSBezierPath(ovalIn: globeRect)
    globePath.lineWidth = 13 * scale
    globePath.stroke()

    for offset in [-46, 0, 46] {
        let y = globeCenter.y + CGFloat(offset) * scale
        let width = sqrt(max(0, globeRadius * globeRadius - pow(y - globeCenter.y, 2))) * 2
        let line = NSBezierPath()
        line.move(to: CGPoint(x: globeCenter.x - width / 2, y: y))
        line.line(to: CGPoint(x: globeCenter.x + width / 2, y: y))
        line.lineWidth = 8 * scale
        line.stroke()
    }

    for factor in [-0.44, 0.44] {
        let meridian = NSBezierPath()
        meridian.move(to: CGPoint(x: globeCenter.x, y: globeCenter.y - globeRadius))
        meridian.curve(
            to: CGPoint(x: globeCenter.x, y: globeCenter.y + globeRadius),
            controlPoint1: CGPoint(x: globeCenter.x + globeRadius * CGFloat(factor), y: globeCenter.y - globeRadius * 0.38),
            controlPoint2: CGPoint(x: globeCenter.x + globeRadius * CGFloat(factor), y: globeCenter.y + globeRadius * 0.38)
        )
        meridian.lineWidth = 8 * scale
        meridian.stroke()
    }

    let fnAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 84 * scale, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.15, alpha: 1)
    ]
    NSString(string: "fn").draw(at: CGPoint(x: 455 * scale, y: 655 * scale), withAttributes: fnAttrs)

    image.unlockFocus()
    return image
}

func drawDMGBackground() -> NSImage {
    let size = NSSize(width: 760, height: 440)
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(origin: .zero, size: size)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 0.88, green: 0.94, blue: 1.0, alpha: 1)
    ])?.draw(in: NSBezierPath(rect: rect), angle: 135)

    context.setFillColor(NSColor(calibratedRed: 0.0, green: 0.48, blue: 0.78, alpha: 0.12).cgColor)
    context.fillEllipse(in: CGRect(x: 520, y: 250, width: 320, height: 260))
    context.setFillColor(NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.38, alpha: 0.10).cgColor)
    context.fillEllipse(in: CGRect(x: -80, y: -80, width: 280, height: 240))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.15, alpha: 1)
    ]
    NSString(string: "Install Globe").draw(at: CGPoint(x: 304, y: 348), withAttributes: titleAttrs)

    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(calibratedRed: 0.28, green: 0.33, blue: 0.39, alpha: 1)
    ]
    NSString(string: "Drag Globe into Applications").draw(at: CGPoint(x: 282, y: 322), withAttributes: subtitleAttrs)

    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 292, y: 202))
    arrow.line(to: CGPoint(x: 467, y: 202))
    arrow.lineWidth = 8
    arrow.lineCapStyle = .round
    NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.15, alpha: 0.28).setStroke()
    arrow.stroke()

    let head = NSBezierPath()
    head.move(to: CGPoint(x: 467, y: 202))
    head.line(to: CGPoint(x: 442, y: 224))
    head.move(to: CGPoint(x: 467, y: 202))
    head.line(to: CGPoint(x: 442, y: 180))
    head.lineWidth = 8
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    image.unlockFocus()
    return image
}

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconSizes {
    try savePNG(drawIcon(size: size), to: iconsetDir.appendingPathComponent(name))
}

let icnsURL = buildAssetsDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "GlobeAssets", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

try savePNG(drawDMGBackground(), to: buildAssetsDir.appendingPathComponent("DMGBackground.png"))
