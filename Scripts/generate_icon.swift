import AppKit
import CoreGraphics
import Foundation

// MARK: - Official HAWK Master App Icon & Logo Asset Generator
// Generates:
// 1. Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (Apple iOS HIG full-bleed 1024x1024 master icon)
// 2. Resources/hawk-logo.png (1024x1024 full-bleed in-app master logo)
// 3. Resources/hawk-glyph.png (1024x1024 transparent alpha ivory glyph, optically centered)

let logoCandidates = [
    "/Users/krtvysingh/.gemini/antigravity/brain/2ee00cb9-3cf8-4f20-af3f-1d4bf529bbd2/.user_uploaded/media_1793727244551_9419d16a.jpg",
    "Resources/hawk-logo.png"
]

var sourceURL: URL?
for candidate in logoCandidates {
    let url = URL(fileURLWithPath: candidate)
    if FileManager.default.fileExists(atPath: url.path) {
        sourceURL = url
        break
    }
}

guard let url = sourceURL,
      let srcRep = NSBitmapImageRep(data: try Data(contentsOf: url)) else {
    print("Error: Could not locate source logo image.")
    exit(1)
}

print("Loaded source image: \(srcRep.pixelsWide) x \(srcRep.pixelsHigh) from \(url.lastPathComponent)")

// 1. Isolate the Hawk Emblem with high-precision subpixel alpha anti-aliasing
let glyphMinX = 326
let glyphMaxX = 700
let glyphMinY = 260
let glyphMaxY = 502
let glyphW = glyphMaxX - glyphMinX + 1
let glyphH = glyphMaxY - glyphMinY + 1

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let glyphCtx = CGContext(
    data: nil,
    width: glyphW,
    height: glyphH,
    bitsPerComponent: 8,
    bytesPerRow: glyphW * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Error: Failed to create glyph context.")
    exit(1)
}

let ivoryR: Double = 0.965
let ivoryG: Double = 0.945
let ivoryB: Double = 0.935

for y in 0..<glyphH {
    let srcY = glyphMinY + y
    for x in 0..<glyphW {
        let srcX = glyphMinX + x
        guard let c = srcRep.colorAt(x: srcX, y: srcY) else { continue }
        let b = (c.redComponent + c.greenComponent + c.blueComponent) / 3.0
        
        let alpha: Double
        if b <= 0.08 {
            alpha = 0.0
        } else if b >= 0.78 {
            alpha = 1.0
        } else {
            let t = (b - 0.08) / (0.78 - 0.08)
            alpha = t * t * (3.0 - 2.0 * t) // smoothstep
        }
        
        if alpha > 0.0 {
            let r = ivoryR * alpha
            let g = ivoryG * alpha
            let bl = ivoryB * alpha
            glyphCtx.setFillColor(red: r, green: g, blue: bl, alpha: alpha)
            glyphCtx.fill(CGRect(x: x, y: glyphH - 1 - y, width: 1, height: 1))
        }
    }
}

guard let isolatedGlyph = glyphCtx.makeImage() else {
    print("Error: Failed to create isolated glyph image.")
    exit(1)
}

// 2. Render Full-Bleed 1024x1024 Master App Icon
let iconSize = 1024
guard let iconCtx = CGContext(
    data: nil,
    width: iconSize,
    height: iconSize,
    bitsPerComponent: 8,
    bytesPerRow: iconSize * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Error: Failed to allocate icon CGContext.")
    exit(1)
}

// Full-bleed dark slate gradient (top #16151B to bottom #0A090E)
let gradientColors = [
    NSColor(red: 0.086, green: 0.082, blue: 0.106, alpha: 1.0).cgColor,
    NSColor(red: 0.047, green: 0.043, blue: 0.063, alpha: 1.0).cgColor,
    NSColor(red: 0.039, green: 0.035, blue: 0.055, alpha: 1.0).cgColor
] as CFArray

let gradientLocations: [CGFloat] = [0.0, 0.5, 1.0]
if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
    iconCtx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 1024),
        end: CGPoint(x: 512, y: 0),
        options: []
    )
}

// Optically centered placement for 1024x1024 canvas
let targetW: CGFloat = 580.0
let targetH: CGFloat = targetW * CGFloat(glyphH) / CGFloat(glyphW)
let baseX = (CGFloat(iconSize) - targetW) / 2.0
let baseY = (CGFloat(iconSize) - targetH) / 2.0
// Apply optical centroid correction (+12.7 pt X, +6.2 pt Y in flipped CG coords)
let opticalX = baseX + 12.7
let opticalY = baseY + 6.2

iconCtx.interpolationQuality = .high
iconCtx.draw(isolatedGlyph, in: CGRect(x: opticalX, y: opticalY, width: targetW, height: targetH))

guard let fullBleedIcon = iconCtx.makeImage() else {
    print("Error: makeImage for full-bleed icon failed.")
    exit(1)
}

let iconRep = NSBitmapImageRep(cgImage: fullBleedIcon)
guard let iconPngData = iconRep.representation(using: .png, properties: [:]) else {
    print("Error: PNG encoding for app icon failed.")
    exit(1)
}

// Write to Assets.xcassets and Resources
let outputDir = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let appIconURL = outputDir.appendingPathComponent("AppIcon-1024.png")
try iconPngData.write(to: appIconURL)

let logoURL = URL(fileURLWithPath: "Resources/hawk-logo.png")
try iconPngData.write(to: logoURL)

// 3. Render Transparent Alpha Glyph (1024x1024)
guard let glyphCanvasCtx = CGContext(
    data: nil,
    width: iconSize,
    height: iconSize,
    bitsPerComponent: 8,
    bytesPerRow: iconSize * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Error: Failed to allocate glyph canvas.")
    exit(1)
}

glyphCanvasCtx.clear(CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
glyphCanvasCtx.interpolationQuality = .high
glyphCanvasCtx.draw(isolatedGlyph, in: CGRect(x: opticalX, y: opticalY, width: targetW, height: targetH))

guard let transparentGlyph = glyphCanvasCtx.makeImage() else {
    print("Error: makeImage for transparent glyph failed.")
    exit(1)
}

let glyphRep = NSBitmapImageRep(cgImage: transparentGlyph)
guard let glyphPngData = glyphRep.representation(using: .png, properties: [:]) else {
    print("Error: PNG encoding for glyph failed.")
    exit(1)
}

let transparentGlyphURL = URL(fileURLWithPath: "Resources/hawk-glyph.png")
try glyphPngData.write(to: transparentGlyphURL)

print("✅ Successfully generated full-bleed AppIcon at: \(appIconURL.path)")
print("✅ Successfully generated master logo at: \(logoURL.path)")
print("✅ Successfully generated transparent glyph at: \(transparentGlyphURL.path)")
