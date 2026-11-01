import SwiftUI

struct EmptyStateView: View {
    var theme: Theme
    var doneToday: Int
    @State private var bob = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Mascot()
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(bob ? -3 : -8))
                    .offset(y: bob ? -4 : 2)
                Sparkle(fill: Theme.lime).frame(width: 38, height: 38).offset(x: 80, y: -72)
                Sparkle(fill: Theme.blue).frame(width: 26, height: 26).offset(x: -86, y: 62)
            }
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
            }
            VStack(spacing: 6) {
                Text("all clear, bestie")
                    .font(.rounded(30, .black))
                    .foregroundStyle(theme.text)
                Text("nothing on deck. touch grass or drop something new up top.")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(theme.sub)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
            }
            if doneToday > 0 {
                Text("\(doneToday) done today · zero carried over")
                    .font(.rounded(13, .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .sticker(Theme.butter, line: theme.line, shadow: theme.shadow, radius: 12, offset: 2)
                    .rotationEffect(.degrees(2))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Pink blob in sunglasses, drawn on a 190×190 grid.
struct Mascot: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 190, y: size.height / 190)
            let ink = Theme.ink
            let stroke = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)

            var outer = Path()
            outer.move(to: CGPoint(x: 95, y: 12))
            outer.addCurve(to: CGPoint(x: 171, y: 84), control1: CGPoint(x: 135, y: 12), control2: CGPoint(x: 171, y: 38))
            outer.addCurve(to: CGPoint(x: 93, y: 176), control1: CGPoint(x: 171, y: 136), control2: CGPoint(x: 137, y: 176))
            outer.addCurve(to: CGPoint(x: 18, y: 92), control1: CGPoint(x: 49, y: 176), control2: CGPoint(x: 18, y: 140))
            outer.addCurve(to: CGPoint(x: 95, y: 12), control1: CGPoint(x: 18, y: 46), control2: CGPoint(x: 55, y: 12))
            outer.closeSubpath()
            ctx.fill(outer, with: .color(.white))
            ctx.stroke(outer, with: .color(ink), style: stroke)

            var inner = Path()
            inner.move(to: CGPoint(x: 95, y: 26))
            inner.addCurve(to: CGPoint(x: 157, y: 86), control1: CGPoint(x: 127, y: 26), control2: CGPoint(x: 157, y: 48))
            inner.addCurve(to: CGPoint(x: 93, y: 164), control1: CGPoint(x: 157, y: 130), control2: CGPoint(x: 129, y: 164))
            inner.addCurve(to: CGPoint(x: 32, y: 92), control1: CGPoint(x: 57, y: 164), control2: CGPoint(x: 32, y: 132))
            inner.addCurve(to: CGPoint(x: 95, y: 26), control1: CGPoint(x: 32, y: 54), control2: CGPoint(x: 63, y: 26))
            inner.closeSubpath()
            ctx.fill(inner, with: .color(Theme.pink))
            ctx.stroke(inner, with: .color(ink), style: stroke)

            var bridge = Path()
            bridge.move(to: CGPoint(x: 50, y: 82))
            bridge.addLine(to: CGPoint(x: 140, y: 82))
            ctx.stroke(bridge, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            for x in [52.0, 102.0] {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: 76, width: 36, height: 24), cornerRadius: 10), with: .color(ink))
                var glint = Path()
                glint.move(to: CGPoint(x: x + 8, y: 82))
                glint.addLine(to: CGPoint(x: x + 16, y: 82))
                ctx.stroke(glint, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            var smile = Path()
            smile.move(to: CGPoint(x: 72, y: 120))
            smile.addCurve(to: CGPoint(x: 118, y: 120), control1: CGPoint(x: 80, y: 132), control2: CGPoint(x: 110, y: 132))
            ctx.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            for x in [58.0, 132.0] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: 111, width: 14, height: 14)), with: .color(Theme.butter))
            }
        }
    }
}

struct Sparkle: View {
    var fill: Color
    var body: some View {
        SparkleShape()
            .fill(fill)
            .overlay(SparkleShape().stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)))
    }
}

struct SparkleShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let o = r.width / 2, i = r.width * 0.09
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - o))
        p.addLine(to: CGPoint(x: c.x + i, y: c.y - i))
        p.addLine(to: CGPoint(x: c.x + o, y: c.y))
        p.addLine(to: CGPoint(x: c.x + i, y: c.y + i))
        p.addLine(to: CGPoint(x: c.x, y: c.y + o))
        p.addLine(to: CGPoint(x: c.x - i, y: c.y + i))
        p.addLine(to: CGPoint(x: c.x - o, y: c.y))
        p.addLine(to: CGPoint(x: c.x - i, y: c.y - i))
        p.closeSubpath()
        return p
    }
}
