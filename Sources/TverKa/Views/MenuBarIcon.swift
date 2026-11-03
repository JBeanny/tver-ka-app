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
                // Same mug as the design (24×24 grid): rounded bottom, open D handle, two wavy steam lines.
                NSGraphicsContext.saveGraphicsState()
                let fit = NSAffineTransform()
                fit.translateX(by: -2.7, yBy: -3.35)
                fit.scale(by: 1.1)
                fit.concat()

                let k: CGFloat = 0.5523 * 5
                let cup = NSBezierPath()
                cup.move(to: NSPoint(x: 4, y: 9))
                cup.line(to: NSPoint(x: 16, y: 9))
                cup.line(to: NSPoint(x: 16, y: 14))
                cup.curve(to: NSPoint(x: 11, y: 19), controlPoint1: NSPoint(x: 16, y: 14 + k), controlPoint2: NSPoint(x: 11 + k, y: 19))
                cup.line(to: NSPoint(x: 9, y: 19))
                cup.curve(to: NSPoint(x: 4, y: 14), controlPoint1: NSPoint(x: 9 - k, y: 19), controlPoint2: NSPoint(x: 4, y: 14 + k))
                cup.close()
                lime.setFill()
                cup.fill()

                let h: CGFloat = 0.5523 * 2.5
                let handle = NSBezierPath()
                handle.move(to: NSPoint(x: 16, y: 11))
                handle.line(to: NSPoint(x: 17.5, y: 11))
                handle.curve(to: NSPoint(x: 20, y: 13.5), controlPoint1: NSPoint(x: 17.5 + h, y: 11), controlPoint2: NSPoint(x: 20, y: 13.5 - h))
                handle.curve(to: NSPoint(x: 17.5, y: 16), controlPoint1: NSPoint(x: 20, y: 13.5 + h), controlPoint2: NSPoint(x: 17.5 + h, y: 16))
                handle.line(to: NSPoint(x: 16, y: 16))

                let steam = NSBezierPath()
                for x: CGFloat in [8, 12] {
                    steam.move(to: NSPoint(x: x, y: 3.5))
                    steam.curve(to: NSPoint(x: x + 1, y: 6), controlPoint1: NSPoint(x: x, y: 4.7), controlPoint2: NSPoint(x: x + 1, y: 4.8))
                }

                // Label color reads as the design's dark ink on a light menu bar and stays visible on a dark one.
                NSColor.labelColor.setStroke()
                for path in [cup, handle, steam] {
                    path.lineWidth = 2.1
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                }
                NSGraphicsContext.restoreGraphicsState()
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
