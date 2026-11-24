import AppKit

func render(scale s: CGFloat, to path: String) {
    let w: CGFloat = 600, h: CGFloat = 460
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * s), pixelsHigh: Int(h * s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    func top(_ y: CGFloat, _ height: CGFloat = 0) -> CGFloat { h - y - height }

    NSColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill()

    let glow = NSGradient(colors: [NSColor(red: 1, green: 0.42, blue: 0.24, alpha: 0.10), .clear])!
    glow.draw(fromCenter: NSPoint(x: w / 2, y: top(40)), radius: 0,
              toCenter: NSPoint(x: w / 2, y: top(40)), radius: 320, options: [])

    NSColor(red: 0.957, green: 0.953, blue: 0.937, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 50, y: top(100, 190), width: 500, height: 190), xRadius: 20, yRadius: 20).fill()

    let orange = NSColor(red: 1, green: 0.42, blue: 0.24, alpha: 1)
    let arrow = NSBezierPath()
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    let y = top(175)
    arrow.move(to: NSPoint(x: 262, y: y))
    arrow.line(to: NSPoint(x: 338, y: y))
    arrow.move(to: NSPoint(x: 324, y: y + 12))
    arrow.line(to: NSPoint(x: 338, y: y))
    arrow.line(to: NSPoint(x: 324, y: y - 12))
    orange.setStroke()
    arrow.stroke()

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: NSColor(red: 0.957, green: 0.953, blue: 0.937, alpha: 1),
        .paragraphStyle: para,
    ]
    let hint: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor(red: 0.52, green: 0.52, blue: 0.56, alpha: 1),
        .paragraphStyle: para,
    ]
    ("FanControl" as NSString).draw(in: NSRect(x: 0, y: top(36, 30), width: w, height: 30), withAttributes: title)
    ("Drag FanControl to Applications" as NSString)
        .draw(in: NSRect(x: 0, y: top(312, 20), width: w, height: 20), withAttributes: hint)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
render(scale: 1, to: out + "/bg.png")
render(scale: 2, to: out + "/bg@2x.png")
