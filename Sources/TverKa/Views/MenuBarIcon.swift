import AppKit

/// The menu bar glyph: the mascot, a pink blob in sunglasses, drawn in color so it's easy to spot.
/// Its outline uses the label color, so it reads on light and dark menu bars alike.
/// With an open priority to-do it gains a butter-yellow dot.
enum MenuBarIcon {
    @MainActor private static var cache: [Bool: NSImage] = [:]

    private static let ink = NSColor(red: 0x17 / 255, green: 0x13 / 255, blue: 0x2B / 255, alpha: 1)
    private static let pink = NSColor(red: 1, green: 0x4F / 255, blue: 0xA3 / 255, alpha: 1)
    private static let butter = NSColor(red: 1, green: 0xE0 / 255, blue: 0x66 / 255, alpha: 1)

    @MainActor static func image(hot: Bool) -> NSImage {
        if let cached = cache[hot] { return cached }
        let size = NSSize(width: 21, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            NSGraphicsContext.saveGraphicsState()
            // Mascot grid is 190×190; the blob spans x 18…171, y 12…176.
            let s: CGFloat = 16.4 / 164
            let t = NSAffineTransform()
            t.translateX(by: 1, yBy: 0.8)
            t.scale(by: s)
            t.translateX(by: -18, yBy: -12)
            t.concat()

            let blob = NSBezierPath()
            blob.move(to: NSPoint(x: 95, y: 12))
            blob.curve(to: NSPoint(x: 171, y: 84), controlPoint1: NSPoint(x: 135, y: 12), controlPoint2: NSPoint(x: 171, y: 38))
            blob.curve(to: NSPoint(x: 93, y: 176), controlPoint1: NSPoint(x: 171, y: 136), controlPoint2: NSPoint(x: 137, y: 176))
            blob.curve(to: NSPoint(x: 18, y: 92), controlPoint1: NSPoint(x: 49, y: 176), controlPoint2: NSPoint(x: 18, y: 140))
            blob.curve(to: NSPoint(x: 95, y: 12), controlPoint1: NSPoint(x: 18, y: 46), controlPoint2: NSPoint(x: 55, y: 12))
            blob.close()
            pink.setFill()
            blob.fill()
            NSColor.labelColor.setStroke()
            blob.lineWidth = 13
            blob.stroke()

            ink.setFill()
            ink.setStroke()
            for x: CGFloat in [44, 104] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 70, width: 44, height: 32), xRadius: 12, yRadius: 12).fill()
            }
            let bridge = NSBezierPath()
            bridge.move(to: NSPoint(x: 80, y: 78))
            bridge.line(to: NSPoint(x: 112, y: 78))
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 66, y: 122))
            smile.curve(to: NSPoint(x: 124, y: 122), controlPoint1: NSPoint(x: 78, y: 140), controlPoint2: NSPoint(x: 112, y: 140))
            for path in [bridge, smile] {
                path.lineWidth = 13
                path.lineCapStyle = .round
                path.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()

            if hot {
                let dot = NSBezierPath(ovalIn: NSRect(x: 13.5, y: 0.5, width: 7, height: 7))
                butter.setFill()
                dot.fill()
                NSColor.labelColor.setStroke()
                dot.lineWidth = 1.2
                dot.stroke()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = hot ? "tver-ka, priority to-dos waiting" : "tver-ka"
        cache[hot] = image
        return image
    }
}

extension MenuBarIcon {
    @MainActor private static var focusCache: [String: NSImage] = [:]

    /// While Focus mode runs: the mascot with a little tomato (focus), or a lime cup (break).
    /// Paused states are drawn at half strength so they're easy to notice.
    @MainActor static func focusImage(onBreak: Bool, paused: Bool) -> NSImage {
        let key = "\(onBreak)-\(paused)"
        if let cached = focusCache[key] { return cached }
        let base = image(hot: false)
        let size = NSSize(width: 21, height: 18)
        let tomatoRed = NSColor(red: 1, green: 0x5A / 255, blue: 0x4E / 255, alpha: 1)
        let leaf = NSColor(red: 0x7B / 255, green: 0xD1 / 255, blue: 0x3B / 255, alpha: 1)
        let lime = NSColor(red: 0xC6 / 255, green: 0xF4 / 255, blue: 0x32 / 255, alpha: 1)
        let result = NSImage(size: size, flipped: true) { _ in
            let alpha: CGFloat = paused ? 0.45 : 1
            // Alpha set before the layer applies to everything drawn inside it, as one image.
            NSGraphicsContext.current?.cgContext.setAlpha(alpha)
            NSGraphicsContext.current?.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
            defer { NSGraphicsContext.current?.cgContext.endTransparencyLayer() }
            if onBreak {
                let cup = NSBezierPath(roundedRect: NSRect(x: 3, y: 6, width: 12, height: 10), xRadius: 3.5, yRadius: 3.5)
                lime.setFill()
                cup.fill()
                NSColor.labelColor.setStroke()
                cup.lineWidth = 1.6
                cup.stroke()
                let handle = NSBezierPath(ovalIn: NSRect(x: 13.5, y: 8.5, width: 5, height: 5))
                handle.lineWidth = 1.6
                handle.stroke()
                for x: CGFloat in [7, 11] {
                    let steam = NSBezierPath()
                    steam.move(to: NSPoint(x: x, y: 1.5))
                    steam.curve(to: NSPoint(x: x, y: 4.5), controlPoint1: NSPoint(x: x + 1.2, y: 2.5), controlPoint2: NSPoint(x: x - 1.2, y: 3.5))
                    steam.lineWidth = 1.2
                    steam.lineCapStyle = .round
                    steam.stroke()
                }
            } else {
                base.draw(in: NSRect(origin: .zero, size: size))
                let tomato = NSBezierPath(ovalIn: NSRect(x: 13, y: 0.8, width: 7.5, height: 7.5))
                tomatoRed.setFill()
                tomato.fill()
                NSColor.labelColor.setStroke()
                tomato.lineWidth = 1.1
                tomato.stroke()
                leaf.setFill()
                NSBezierPath(ovalIn: NSRect(x: 15, y: 0, width: 3.5, height: 2)).fill()
            }
            return true
        }
        result.isTemplate = false
        result.accessibilityDescription = onBreak ? "tver-ka, on a break" : "tver-ka, focusing"
        focusCache[key] = result
        return result
    }
}
