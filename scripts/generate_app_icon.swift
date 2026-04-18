#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Configuration

let accentColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) // Pure black background
let symbolName = "building.columns.fill"

// Resolve repo root: …/scripts/generate_app_icon.swift → parent of `scripts` is repo
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = repoRoot.appendingPathComponent("AppIcons", isDirectory: true).path

// Icon sizes needed for iOS app (point size × scale → pixel size on export)
let iconSizes: [(size: CGFloat, scale: CGFloat, name: String)] = [
    // iPhone
    (20, 2, "Icon-20@2x"),
    (20, 3, "Icon-20@3x"),
    (29, 2, "Icon-29@2x"),
    (29, 3, "Icon-29@3x"),
    (40, 2, "Icon-40@2x"),
    (40, 3, "Icon-40@3x"),
    (60, 2, "Icon-60@2x"),
    (60, 3, "Icon-60@3x"),

    // iPad
    (20, 1, "Icon-20"),
    (29, 1, "Icon-29"),
    (40, 1, "Icon-40"),
    (76, 1, "Icon-76"),
    (76, 2, "Icon-76@2x"),
    (83.5, 2, "Icon-83.5@2x"),

    // App Store
    (1024, 1, "Icon-1024"),
]

// MARK: - Rendering

/// Renders at **exact pixel** width/height. (Drawing at point size then scaling up — e.g. 60→180 — was causing blurry, pixelated PNGs.)
func renderIconPNG(pixelSize: CGFloat, filename: String) -> Bool {
    let w = Int(round(pixelSize))
    let h = Int(round(pixelSize))
    guard w > 0, h > 0 else {
        print("❌ Invalid pixel size for \(filename)")
        return false
    }

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: w,
        pixelsHigh: h,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("❌ Failed to create bitmap for \(filename)")
        return false
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        print("❌ Failed to create graphics context for \(filename)")
        return false
    }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.shouldAntialias = true

    let rect = NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
    accentColor.setFill()
    NSBezierPath(rect: rect).fill()

    let symbolPointSize = CGFloat(w) * 0.6
    let sizeConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
    let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
    guard let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(sizeConfig.applying(colorConfig))
    else {
        print("❌ Failed to create SF Symbol: \(symbolName)")
        return false
    }

    var symSize = baseSymbol.size
    if symSize.width < 1 || symSize.height < 1 {
        symSize = NSSize(width: symbolPointSize, height: symbolPointSize)
    }

    let pad: CGFloat = 0.86
    let s = pad * min(CGFloat(w) / symSize.width, CGFloat(h) / symSize.height)
    let drawW = symSize.width * s
    let drawH = symSize.height * s
    let symbolRect = NSRect(
        x: (CGFloat(w) - drawW) / 2,
        y: (CGFloat(h) - drawH) / 2,
        width: drawW,
        height: drawH
    )
    let src = NSRect(origin: .zero, size: symSize)

    baseSymbol.draw(
        in: symbolRect,
        from: src,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: nil
    )

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("❌ Failed to create PNG data for \(filename)")
        return false
    }

    let filePath = "\(outputDirectory)/\(filename).png"
    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("✅ Created: \(filename).png (\(w)×\(h))")
        return true
    } catch {
        print("❌ Failed to write \(filename): \(error)")
        return false
    }
}

// MARK: - Main Execution

print("VTOP Chennai — App Icon Generator")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("SF Symbol: \(symbolName)")
print("Background: black · Symbol: white (palette)")
print("Output: \(outputDirectory)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

do {
    try FileManager.default.createDirectory(
        atPath: outputDirectory,
        withIntermediateDirectories: true,
        attributes: nil
    )
    print("📁 Output directory ready\n")
} catch {
    print("❌ Failed to create directory: \(error)")
    exit(1)
}

var successCount = 0
var failCount = 0

for (size, scale, name) in iconSizes {
    let pixelSize = size * scale
    if renderIconPNG(pixelSize: pixelSize, filename: name) {
        successCount += 1
    } else {
        failCount += 1
    }
}

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Successfully generated: \(successCount)/\(iconSizes.count)")
if failCount > 0 {
    print("❌ Failed: \(failCount)")
}
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("\nNext steps:")
print("1. Open ios-vtop-chennai.xcodeproj in Xcode")
print("2. Assets.xcassets → AppIcon")
print("3. Drag PNGs from AppIcons/ into the matching slots (or replace existing)")
print("4. Product → Clean Build Folder if the home-screen icon looks cached")
print()
