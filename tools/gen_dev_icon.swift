// gen_dev_icon.swift — derive a visually distinct "DEV" app icon from the
// release AppIcon so the Debug build is unmistakable in the Accessibility list.
//
// Overlays a red bottom band (with "DEV" text at legible sizes) onto every icon
// PNG. Dependency-free: uses AppKit, run with the system `swift`.
//
// Usage: swift tools/gen_dev_icon.swift <srcAppIconSetDir> <dstAppIconSetDir>
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: gen_dev_icon.swift <srcDir> <dstDir>\n".data(using: .utf8)!)
    exit(2)
}
let srcDir = args[1], dstDir = args[2]

let files = ["icon_16x16.png", "icon_16x16@2x.png", "icon_32x32.png", "icon_32x32@2x.png",
             "icon_128x128.png", "icon_128x128@2x.png", "icon_256x256.png", "icon_256x256@2x.png",
             "icon_512x512.png", "icon_512x512@2x.png"]

for f in files {
    let srcPath = "\(srcDir)/\(f)"
    guard let data = FileManager.default.contents(atPath: srcPath),
          let rep = NSBitmapImageRep(data: data) else {
        FileHandle.standardError.write("skip (read fail): \(f)\n".data(using: .utf8)!)
        continue
    }
    let w = rep.pixelsWide, h = rep.pixelsHigh
    guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    let full = NSRect(x: 0, y: 0, width: w, height: h)
    rep.draw(in: full)

    // Bottom band (origin is bottom-left in this context).
    let bandH = CGFloat(h) * 0.34
    NSColor(red: 0.85, green: 0.18, blue: 0.14, alpha: 0.92).setFill()
    NSRect(x: 0, y: 0, width: CGFloat(w), height: bandH).fill()

    // "DEV" text only where it stays legible (skip 16/32 px tiles).
    if w >= 64 {
        let fontSize = bandH * 0.60
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para,
        ]
        let s = NSAttributedString(string: "DEV", attributes: attrs)
        let sz = s.size()
        s.draw(at: NSPoint(x: (CGFloat(w) - sz.width) / 2, y: (bandH - sz.height) / 2))
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let png = out.representation(using: .png, properties: [:]) else { continue }
    do {
        try png.write(to: URL(fileURLWithPath: "\(dstDir)/\(f)"))
        print("wrote \(f) (\(w)x\(h))")
    } catch {
        FileHandle.standardError.write("write fail: \(f): \(error)\n".data(using: .utf8)!)
    }
}
