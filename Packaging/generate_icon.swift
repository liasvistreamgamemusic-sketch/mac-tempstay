#!/usr/bin/env swift
import AppKit

// Renders a 1024×1024 master app icon: a rounded "squircle" with a teal→indigo
// gradient and a white tray/shelf glyph (the app holds items on a shelf).
// Usage: swift generate_icon.swift <output.png>

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let side: CGFloat = 1024

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("No graphics context\n", stderr)
    exit(1)
}

// Rounded-rect background with an inset matching Apple's icon grid.
let inset: CGFloat = side * 0.085
let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let radius = rect.width * 0.2237
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()

let colors = [
    CGColor(red: 0.16, green: 0.72, blue: 0.70, alpha: 1.0),
    CGColor(red: 0.27, green: 0.36, blue: 0.86, alpha: 1.0)
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: rect.minX, y: rect.maxY),
    end: CGPoint(x: rect.maxX, y: rect.minY),
    options: []
)

// White tray glyph centred on the icon — the shelf that holds dropped items.
let symbolConfig = NSImage.SymbolConfiguration(pointSize: side * 0.46, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let symbolSize = symbol.size
    let origin = CGPoint(x: (side - symbolSize.width) / 2, y: (side - symbolSize.height) / 2)
    symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote icon to \(outputPath)")
} catch {
    fputs("Failed to write \(outputPath): \(error)\n", stderr)
    exit(1)
}
