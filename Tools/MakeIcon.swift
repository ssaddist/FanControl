import AppKit
import CoreGraphics

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
func gradient(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
}

let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(rgb(0.2, 0.1, 0.4)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0.62, 0.20, 0.55), rgb(0.36, 0.14, 0.56), rgb(0.17, 0.09, 0.38)], [0, 0.5, 1]),
                       start: CGPoint(x: tile.minX, y: tile.minY), end: CGPoint(x: tile.maxX, y: tile.maxY), options: [])
let c = CGPoint(x: size / 2, y: size / 2)
ctx.drawRadialGradient(gradient([rgb(1, 0.42, 0.75, 0.55), rgb(1, 0.42, 0.75, 0)], [0, 1]),
                       startCenter: c, startRadius: 0, endCenter: c, endRadius: 360, options: [])
ctx.restoreGState()

let ringR: CGFloat = 300, ringW: CGFloat = 46
ctx.setLineCap(.round)
ctx.setLineWidth(ringW)
ctx.setStrokeColor(rgb(1, 1, 1, 0.12))
ctx.addArc(center: c, radius: ringR, startAngle: .pi * 1.25, endAngle: -.pi * 0.25, clockwise: true)
ctx.strokePath()

let stops: [(CGFloat, CGFloat, CGFloat)] = [(0.32, 0.86, 0.98), (0.35, 0.90, 0.70), (0.98, 0.85, 0.35), (1.0, 0.45, 0.45)]
func colorAt(_ t: CGFloat) -> CGColor {
    let x = t * CGFloat(stops.count - 1), i = min(Int(x), stops.count - 2), f = x - CGFloat(i)
    let a = stops[i], b = stops[i + 1]
    return rgb(a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
}
let start = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5 * 0.72, steps = 120
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 30, color: rgb(1, 0.6, 0.6, 0.6))
for s in 0..<steps {
    let t0 = CGFloat(s) / CGFloat(steps), t1 = CGFloat(s + 1) / CGFloat(steps)
    ctx.setStrokeColor(colorAt(t0))
    ctx.setLineCap(s == 0 || s == steps - 1 ? .round : .butt)
    ctx.addArc(center: c, radius: ringR, startAngle: start - sweep * t0, endAngle: start - sweep * t1 - 0.002, clockwise: true)
    ctx.strokePath()
}
ctx.restoreGState()

let bladeCount = 7
let rIn: CGFloat = 62, rOut: CGFloat = 215
func polar(_ r: CGFloat, _ a: CGFloat) -> CGPoint { CGPoint(x: r * cos(a), y: r * sin(a)) }
func blade(_ base: CGFloat) -> CGPath {
    let p = CGMutablePath(), n = 40
    let twist = { (f: CGFloat) in CGFloat.pi / 180 * 55 * pow(f, 1.4) }
    let width = { (f: CGFloat) in CGFloat.pi / 180 * (16 + 24 * sin(f * .pi / 2)) }
    var trailing: [CGPoint] = []
    for i in 0...n {
        let f = CGFloat(i) / CGFloat(n), r = rIn + (rOut - rIn) * f
        let lead = polar(r, base + twist(f))
        i == 0 ? p.move(to: lead) : p.addLine(to: lead)
        trailing.append(polar(r, base + twist(f) + width(f)))
    }

    let mid = base + twist(1) + width(1) / 2
    p.addQuadCurve(to: trailing.last!, control: polar(rOut + 34, mid))
    for pt in trailing.reversed() { p.addLine(to: pt) }
    p.closeSubpath()
    return p
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: rgb(0.1, 0, 0.2, 0.45))
ctx.translateBy(x: c.x, y: c.y)
ctx.setFillColor(rgb(1, 1, 1, 0.96))
for i in 0..<bladeCount {
    ctx.addPath(blade(CGFloat(i) * 2 * .pi / CGFloat(bladeCount)))
    ctx.fillPath()
}
ctx.restoreGState()

ctx.setFillColor(rgb(1, 1, 1))
ctx.fillEllipse(in: CGRect(x: c.x - 72, y: c.y - 72, width: 144, height: 144))
ctx.setFillColor(rgb(0.45, 0.16, 0.55))
ctx.fillEllipse(in: CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
