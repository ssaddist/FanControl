import AppKit
import CoreGraphics

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: hex(0x000000, 0.45))
ctx.addPath(tilePath); ctx.setFillColor(hex(0x0B0B0C)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
let sheen = CGGradient(colorsSpace: cs, colors: [hex(0x18181B), hex(0x0B0B0C)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])
ctx.restoreGState()

ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
ctx.setStrokeColor(hex(0x303036)); ctx.setLineWidth(4); ctx.strokePath()

let k: CGFloat = 23
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: size / 2 + (x - 12) * k, y: size / 2 - (y - 12) * k) }

ctx.setLineCap(.round)
ctx.setLineWidth(2.2 * k)
ctx.setStrokeColor(hex(0xF4F3EF))
ctx.addArc(center: pt(12, 12), radius: 9 * k, startAngle: .pi * 1.25, endAngle: -.pi * 0.25, clockwise: true)
ctx.strokePath()

ctx.move(to: pt(12, 12)); ctx.addLine(to: pt(8.2, 8.2))
ctx.strokePath()

let dot = pt(19.63, 7.23), r = 2.6 * k
ctx.setFillColor(hex(0x0B0B0C))
ctx.fillEllipse(in: CGRect(x: dot.x - r - 18, y: dot.y - r - 18, width: 2 * r + 36, height: 2 * r + 36))
ctx.setFillColor(hex(0xFF6B3D))
ctx.fillEllipse(in: CGRect(x: dot.x - r, y: dot.y - r, width: 2 * r, height: 2 * r))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
