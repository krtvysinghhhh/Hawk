import AppKit
import CoreGraphics
import Foundation

let size = CGSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

// 1. Deep space background gradient
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(red: 0.05, green: 0.03, blue: 0.12, alpha: 1.0).cgColor,
    NSColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 1.0).cgColor
] as CFArray
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    cg.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
}

// 2. Central ambient violet/ember glow
let glowColors = [
    NSColor(red: 0.85, green: 0.20, blue: 0.55, alpha: 0.35).cgColor,
    NSColor(red: 0.55, green: 0.15, blue: 0.85, alpha: 0.18).cgColor,
    NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
] as CFArray
if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.45, 1.0]) {
    cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: 512, y: 530), startRadius: 10, endCenter: CGPoint(x: 512, y: 530), endRadius: 480, options: [])
}

// 3. Audio Waveform Bars (Vertical equalizer rhythm)
let barHeights: [CGFloat] = [70, 130, 220, 340, 270, 390, 480, 390, 270, 340, 220, 130, 70]
let barWidth: CGFloat = 20
let barSpacing: CGFloat = 18
let totalWidth = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * barSpacing
let startX = (1024 - totalWidth) / 2.0

let waveColors = [
    NSColor(red: 1.0, green: 0.30, blue: 0.35, alpha: 0.95).cgColor, // Coral/Ember
    NSColor(red: 0.70, green: 0.25, blue: 0.95, alpha: 0.95).cgColor  // Violet
] as CFArray

for (i, h) in barHeights.enumerated() {
    let x = startX + CGFloat(i) * (barWidth + barSpacing)
    let y = 512.0 - (h / 2.0)
    let rect = CGRect(x: x, y: y, width: barWidth, height: h)
    let path = CGPath(roundedRect: rect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0, transform: nil)
    
    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    if let barGrad = CGGradient(colorsSpace: colorSpace, colors: waveColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(barGrad, start: CGPoint(x: x, y: y), end: CGPoint(x: x, y: y + h), options: [])
    }
    cg.restoreGState()
}

// 4. Hawk Falcon Wings Overlay (Geometric chevron silhouette)
cg.saveGState()
let wingPath = CGMutablePath()

// Left Wing
wingPath.move(to: CGPoint(x: 512, y: 690))
wingPath.addLine(to: CGPoint(x: 230, y: 790))
wingPath.addLine(to: CGPoint(x: 340, y: 640))
wingPath.addLine(to: CGPoint(x: 210, y: 680))
wingPath.addLine(to: CGPoint(x: 360, y: 520))
wingPath.addLine(to: CGPoint(x: 512, y: 430))

// Right Wing (symmetric)
wingPath.addLine(to: CGPoint(x: 664, y: 520))
wingPath.addLine(to: CGPoint(x: 814, y: 680))
wingPath.addLine(to: CGPoint(x: 684, y: 640))
wingPath.addLine(to: CGPoint(x: 794, y: 790))
wingPath.addLine(to: CGPoint(x: 512, y: 690))
wingPath.closeSubpath()

cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor(red: 1.0, green: 0.25, blue: 0.5, alpha: 0.7).cgColor)
cg.addPath(wingPath)
cg.setLineWidth(14)
cg.setLineJoin(.round)
cg.setStrokeColor(NSColor(red: 1.0, green: 0.95, blue: 1.0, alpha: 0.95).cgColor)
cg.strokePath()
cg.restoreGState()

// 5. Center Falcon Beak / Accent Crest
cg.saveGState()
let crestPath = CGMutablePath()
crestPath.move(to: CGPoint(x: 512, y: 720))
crestPath.addLine(to: CGPoint(x: 485, y: 630))
crestPath.addLine(to: CGPoint(x: 512, y: 580))
crestPath.addLine(to: CGPoint(x: 539, y: 630))
crestPath.closeSubpath()

cg.setFillColor(NSColor(red: 1.0, green: 0.40, blue: 0.35, alpha: 1.0).cgColor)
cg.addPath(crestPath)
cg.fillPath()
cg.restoreGState()

NSGraphicsContext.restoreGraphicsState()

let outputDir = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let imageURL = outputDir.appendingPathComponent("AppIcon-1024.png")
if let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: imageURL)
    print("Successfully wrote HAWK App Icon to \(imageURL.path)")
}
