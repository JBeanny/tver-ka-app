import SwiftUI

struct Theme {
    static let ink = Color(hex: 0x17132B)
    static let pink = Color(hex: 0xFF4FA3)
    static let lime = Color(hex: 0xC6F432)
    static let blue = Color(hex: 0x3D5AFE)
    static let butter = Color(hex: 0xFFE066)
    static let danger = Color(hex: 0xB3123E)

    let bg: Color
    let card: Color
    let text: Color
    let sub: Color
    let line: Color
    let shadow: Color
    let brand: Color
    let missedFill: Color
    let missedLine: Color
    let missedText: Color

    static func of(_ scheme: ColorScheme) -> Theme {
        scheme == .dark
            ? Theme(
                bg: Color(hex: 0x15111F), card: Color(hex: 0x241D35), text: Color(hex: 0xF6F2FF),
                sub: Color(hex: 0xBDB4D6), line: Color(hex: 0xF6F2FF), shadow: pink, brand: Color(hex: 0xFF6FB5),
                missedFill: Color(hex: 0x1F1A2C), missedLine: Color(hex: 0x8A82A3), missedText: Color(hex: 0xBDB4D6))
            : Theme(
                bg: Color(hex: 0xF3EFFF), card: .white, text: ink,
                sub: Color(hex: 0x5B5470), line: ink, shadow: ink, brand: Color(hex: 0xE6197F),
                missedFill: Color(hex: 0xEAE6F4), missedLine: Color(hex: 0x5B5470), missedText: Color(hex: 0x3B3550))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Thick outline + hard offset shadow: the "sticker" look.
struct Sticker: ViewModifier {
    var fill: Color
    var line: Color
    var shadow: Color?
    var radius: CGFloat = 16
    var lineWidth: CGFloat = 2.5
    var offset: CGFloat = 3
    var dashed = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(line, style: StrokeStyle(lineWidth: lineWidth, dash: dashed ? [6, 4] : [])))
            .background(shape.fill(shadow ?? .clear).offset(x: offset, y: offset))
    }
}

extension View {
    func sticker(
        _ fill: Color, line: Color, shadow: Color? = nil, radius: CGFloat = 16,
        lineWidth: CGFloat = 2.5, offset: CGFloat = 3, dashed: Bool = false
    ) -> some View {
        modifier(Sticker(
            fill: fill, line: line, shadow: shadow, radius: radius,
            lineWidth: lineWidth, offset: offset, dashed: dashed))
    }
}

/// A small tilted label, e.g. "rolled ×2".
struct StickerBadge: View {
    var text: String
    var icon: String?
    var fill: Color
    var textColor: Color = Theme.ink
    var line: Color = Theme.ink
    var tilt: Double = -2
    var size: CGFloat = 11
    var capsule = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: size, weight: .black)) }
            Text(text).font(.rounded(size, .black)).lineLimit(1)
        }
        .fixedSize()
        .foregroundStyle(textColor)
        .padding(.horizontal, capsule ? 9 : 7)
        .padding(.vertical, capsule ? 3 : 1.5)
        .sticker(fill, line: line, radius: capsule ? 99 : 6, lineWidth: 2)
        .rotationEffect(.degrees(tilt))
    }
}

struct Wordmark: View {
    var theme: Theme
    var body: some View {
        ZStack {
            Text("Tver Ka").foregroundStyle(theme.line).offset(x: 2, y: 2)
            Text("Tver Ka").foregroundStyle(theme.brand)
        }
        .font(.rounded(26, .black))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tver Ka")
    }
}

/// Square outlined icon button used in headers.
struct StickerIconButton: View {
    var systemImage: String
    var label: String
    var theme: Theme
    var badge: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(theme.text)
                .frame(width: 40, height: 40)
                .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 13, offset: 2)
                .overlay(alignment: .topTrailing) {
                    if let badge, badge > 0 {
                        Text("\(badge)")
                            .font(.rounded(11, .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .sticker(Theme.blue, line: theme.line, radius: 99, lineWidth: 2)
                            .offset(x: 8, y: -8)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct StickerToggleStyle: ToggleStyle {
    var onColor: Color
    var line: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        let track = RoundedRectangle(cornerRadius: 16, style: .circular)
        return ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            track.fill(configuration.isOn ? onColor : Color(hex: 0xDCD6EA))
            track.strokeBorder(line, lineWidth: 2.5)
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(line, lineWidth: 2))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 4)
        }
        .frame(width: 54, height: 32)
        .contentShape(track)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { configuration.isOn.toggle() }
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
