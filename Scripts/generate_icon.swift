import AppKit
import CoreGraphics
import Foundation

// Script to extract and generate the official HAWK 1024x1024 Master App Icon and master logo asset.
let currentDir = FileManager.default.currentDirectoryPath
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
      let srcImage = NSImage(contentsOf: url),
      let srcRep = srcImage.representations.first as? NSBitmapImageRep,
      let cgImage = srcRep.cgImage else {
    print("Error: Could not locate source logo image.")
    exit(1)
}

let outSize = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

guard let ctx = CGContext(
    data: nil,
    width: outSize,
    height: outSize,
    bitsPerComponent: 8,
    bytesPerRow: outSize * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    print("Error: Could not allocate CGContext.")
    exit(1)
}

// If processing raw upload, crop central rounded square (544x544 at x=239, y=110)
let imageToDraw: CGImage
if srcRep.pixelsWide == 1024 && (srcRep.pixelsHigh == 765 || srcRep.pixelsHigh == 764) {
    let cropRect = CGRect(x: 239, y: 110, width: 544, height: 544)
    imageToDraw = cgImage.cropping(to: cropRect) ?? cgImage
} else {
    imageToDraw = cgImage
}

ctx.interpolationQuality = .high
ctx.draw(imageToDraw, in: CGRect(x: 0, y: 0, width: outSize, height: outSize))

guard let outImage = ctx.makeImage() else {
    print("Error: makeImage failed.")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: outImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Error: PNG compression failed.")
    exit(1)
}

let outputDir = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let iconURL = outputDir.appendingPathComponent("AppIcon-1024.png")
try pngData.write(to: iconURL)

let logoURL = URL(fileURLWithPath: "Resources/hawk-logo.png")
try pngData.write(to: logoURL)

print("Successfully generated official HAWK Master App Icon at \(iconURL.path)")
print("Successfully generated official HAWK in-app logo at \(logoURL.path)")
