import AppKit

let size = 1024
let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))

let image = NSImage(size: rect.size, flipped: false) { _ in
    // Blue rounded background
    let bg = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
    NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setFill()
    bg.fill()

    // Globe symbol in white
    let config = NSImage.SymbolConfiguration(pointSize: 620, weight: .light)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let globe = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let iconSize = globe.size
        let origin = CGPoint(x: (rect.width - iconSize.width) / 2,
                             y: (rect.height - iconSize.height) / 2)
        globe.draw(in: CGRect(origin: origin, size: iconSize))
    }
    return true
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = rect.size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "AppIcon.png"))
print("AppIcon.png written")
