#!/usr/bin/env swift
// Draws the Tver Ka app icon and writes Resources/AppIcon.icns (plus a 1024px preview PNG).
// Usage: swift Scripts/make-icons.swift
import AppKit

let ink = NSColor(red: 0x17 / 255, green: 0x13 / 255, blue: 0x2B / 255, alpha: 1)
let pink = NSColor(red: 1, green: 0x4F / 255, blue: 0xA3 / 255, alpha: 1)
let lime = NSColor(red: 0xC6 / 255, green: 0xF4 / 255, blue: 0x32 / 255, alpha: 1)
let blue = NSColor(red: 0x3D / 255, green: 0x5A / 255, blue: 0xFE / 255, alpha: 1)
let butter = NSColor(red: 1, green: 0xE0 / 255, blue: 0x66 / 255, alpha: 1)

func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

/// Mascot outline on its 190×190 grid.
func blobPath(inner: Bool) -> NSBezierPath {
    let b = NSBezierPath()
    if inner {
        b.move(to: p(95, 26))
        b.curve(to: p(157, 86), controlPoint1: p(127, 26), controlPoint2: p(157, 48))
        b.curve(to: p(93, 164), controlPoint1: p(157, 130), controlPoint2: p(129, 164))
        b.curve(to: p(32, 92), controlPoint1: p(57, 164), controlPoint2: p(32, 132))
        b.curve(to: p(95, 26), controlPoint1: p(32, 54), controlPoint2: p(63, 26))
    } else {
        b.move(to: p(95, 12))
        b.curve(to: p(171, 84), controlPoint1: p(135, 12), controlPoint2: p(171, 38))
        b.curve(to: p(93, 176), controlPoint1: p(171, 136), controlPoint2: p(137, 176))
        b.curve(to: p(18, 92), controlPoint1: p(49, 176), controlPoint2: p(18, 140))
        b.curve(to: p(95, 12), controlPoint1: p(18, 46), controlPoint2: p(55, 12))
    }
    b.close()
    return b
}

func sparkle(center c: NSPoint, radius o: CGFloat) -> NSBezierPath {
    let i = o * 0.26
    let s = NSBezierPath()
    s.move(to: p(c.x, c.y - o))
    s.line(to: p(c.x + i, c.y - i)); s.line(to: p(c.x + o, c.y)); s.line(to: p(c.x + i, c.y + i))
    s.line(to: p(c.x, c.y + o)); s.line(to: p(c.x - i, c.y + i)); s.line(to: p(c.x - o, c.y)); s.line(to: p(c.x - i, c.y - i))
    s.close()
    return s
}

func stroke(_ path: NSBezierPath, _ color: NSColor, _ width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

/// Draws the icon on a 1024×1024 top-left-origin canvas.
func drawIcon() {
    // Tile: hard offset shadow, then the pink sticker with a thick outline.
    let tile = NSRect(x: 100, y: 96, width: 808, height: 808)
    ink.setFill()
    NSBezierPath(roundedRect: tile.offsetBy(dx: 22, dy: 24), xRadius: 184, yRadius: 184).fill()
    let face = NSBezierPath(roundedRect: tile, xRadius: 184, yRadius: 184)
    pink.setFill(); face.fill()
    stroke(face, ink, 24)

    // Sparkles.
    for (c, r, color) in [(p(770, 250), CGFloat(70), lime), (p(236, 760), 46, blue), (p(250, 250), 30, butter)] {
        let s = sparkle(center: c, radius: r)
        color.setFill(); s.fill()
        stroke(s, ink, 9)
    }

    // Mascot: white sticker border, lime body, shades, smile.
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: 500, yBy: 520)
    t.rotate(byDegrees: -6)
    t.scale(by: 3.1)
    t.translateX(by: -95, yBy: -94)
    t.concat()

    let outer = blobPath(inner: false)
    NSColor.white.setFill(); outer.fill()
    stroke(outer, ink, 4.5)
    let inner = blobPath(inner: true)
    lime.setFill(); inner.fill()
    stroke(inner, ink, 4.5)

    let bridge = NSBezierPath(); bridge.move(to: p(50, 82)); bridge.line(to: p(140, 82))
    stroke(bridge, ink, 6)
    for x in [CGFloat(50), 102] {
        ink.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 74, width: 38, height: 27), xRadius: 11, yRadius: 11).fill()
        let glint = NSBezierPath(); glint.move(to: p(x + 9, 81)); glint.line(to: p(x + 18, 81))
        stroke(glint, .white, 3.5)
    }
    let smile = NSBezierPath()
    smile.move(to: p(72, 120))
    smile.curve(to: p(118, 120), controlPoint1: p(80, 133), controlPoint2: p(110, 133))
    stroke(smile, ink, 6)
    pink.setFill()
    for x in [CGFloat(56), 134] { NSBezierPath(ovalIn: NSRect(x: x - 8, y: 110, width: 16, height: 16)).fill() }
    NSGraphicsContext.restoreGraphicsState()

    // Check badge, tilted like a sticker.
    let badge = NSRect(x: 618, y: 624, width: 210, height: 210)
    ink.setFill(); NSBezierPath(ovalIn: badge.offsetBy(dx: 10, dy: 12)).fill()
    let circle = NSBezierPath(ovalIn: badge)
    butter.setFill(); circle.fill()
    stroke(circle, ink, 18)
    let check = NSBezierPath()
    check.move(to: p(668, 732)); check.line(to: p(708, 772)); check.line(to: p(780, 686))
    stroke(check, ink, 30)
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    // Flip to a top-left origin and scale the 1024 canvas down to this size.
    let s = CGFloat(pixels) / 1024
    let t = NSAffineTransform()
    t.translateX(by: 0, yBy: CGFloat(pixels))
    t.scaleX(by: s, yBy: -s)
    t.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try png(pixels: 1024).write(to: resources.appendingPathComponent("AppIcon-preview.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
