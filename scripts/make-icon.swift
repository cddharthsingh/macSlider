// Renders the app icon: a graphite trackpad with a lit rail on each edge.
//   swift scripts/make-icon.swift build/icon.png
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "build/icon.png"
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // macOS icon grid: 1024 canvas, ~824 squircle.
    let tile: CGFloat = 824
    let inset = (size - tile) / 2
    let tileRect = CGRect(x: inset, y: inset, width: tile, height: tile)
    let tilePath = CGPath(roundedRect: tileRect, cornerWidth: tile * 0.225, cornerHeight: tile * 0.225, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(CGColor(gray: 0.09, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(colorsSpace: space,
                        colors: [CGColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1),
                                 CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    // Trackpad surface.
    let padW: CGFloat = 560, padH: CGFloat = 400
    let pad = CGRect(x: (size - padW) / 2, y: (size - padH) / 2, width: padW, height: padH)
    let padPath = CGPath(roundedRect: pad, cornerWidth: 56, cornerHeight: 56, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: CGColor(gray: 0, alpha: 0.55))
    ctx.addPath(padPath); ctx.setFillColor(CGColor(gray: 0.13, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(padPath); ctx.clip()
    let sheen = CGGradient(colorsSpace: space,
                           colors: [CGColor(gray: 1, alpha: 0.10), CGColor(gray: 1, alpha: 0.0)] as CFArray,
                           locations: [0, 0.6])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: pad.maxY), end: CGPoint(x: 0, y: pad.minY), options: [])
    ctx.restoreGState()
    ctx.addPath(padPath); ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.16)); ctx.setLineWidth(3); ctx.strokePath()

    // Edge rails: gold on the left at 65%, sky on the right at 45%.
    func rail(x: CGFloat, level: CGFloat, color: CGColor) {
        let w: CGFloat = 18
        let full = CGRect(x: x - w / 2, y: pad.minY + 36, width: w, height: pad.height - 72)
        ctx.addPath(CGPath(roundedRect: full, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil))
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.08)); ctx.fillPath()
        let lit = CGRect(x: full.minX, y: full.minY, width: w, height: full.height * level)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 46, color: color.copy(alpha: 0.95))
        ctx.addPath(CGPath(roundedRect: lit, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil))
        ctx.setFillColor(color); ctx.fillPath()
        ctx.restoreGState()
    }
    rail(x: pad.minX + 34, level: 0.65, color: CGColor(red: 0.98, green: 0.80, blue: 0.45, alpha: 1))
    rail(x: pad.maxX - 34, level: 0.45, color: CGColor(red: 0.55, green: 0.76, blue: 1.00, alpha: 1))

    // Finger on the right rail.
    let finger = CGPoint(x: pad.maxX - 34, y: pad.minY + 36 + (pad.height - 72) * 0.45)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24, color: CGColor(gray: 1, alpha: 0.6))
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.95))
    ctx.fillEllipse(in: CGRect(x: finger.x - 22, y: finger.y - 22, width: 44, height: 44))
    ctx.restoreGState()
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.35)); ctx.setLineWidth(4)
    ctx.strokeEllipse(in: CGRect(x: finger.x - 44, y: finger.y - 44, width: 88, height: 88))

    ctx.restoreGState()
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
