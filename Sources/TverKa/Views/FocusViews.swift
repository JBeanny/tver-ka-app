import SwiftUI
import TverKaCore

extension Theme {
    static let tomato = Color(hex: 0xFF5A4E)
    static let leaf = Color(hex: 0x7BD13B)
}

/// The little outlined tomato used for Focus mode, drawn on a 24×24 grid.
struct TomatoIcon: View {
    var size: CGFloat = 16
    var line: Color = Theme.ink
    var fill: Color = Theme.tomato
    var showsPlay = false

    var body: some View {
        Canvas { ctx, canvas in
            ctx.scaleBy(x: canvas.width / 24, y: canvas.height / 24)
            let body = Path(ellipseIn: CGRect(x: 4, y: 5.5, width: 16, height: 16))
            ctx.fill(body, with: .color(fill))
            ctx.stroke(body, with: .color(line), lineWidth: 2)

            var leaf = Path()
            leaf.move(to: CGPoint(x: 8, y: 6.6))
            leaf.addCurve(to: CGPoint(x: 16, y: 6.6), control1: CGPoint(x: 10.6, y: 5), control2: CGPoint(x: 13.4, y: 5))
            leaf.addCurve(to: CGPoint(x: 8, y: 6.6), control1: CGPoint(x: 13.6, y: 9), control2: CGPoint(x: 10.4, y: 9))
            ctx.fill(leaf, with: .color(Theme.leaf))
            ctx.stroke(leaf, with: .color(line), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

            var stem = Path()
            stem.move(to: CGPoint(x: 12, y: 5.5))
            stem.addLine(to: CGPoint(x: 12, y: 3))
            ctx.stroke(stem, with: .color(line), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            if showsPlay {
                var play = Path()
                play.move(to: CGPoint(x: 10.5, y: 11))
                play.addLine(to: CGPoint(x: 10.5, y: 16))
                play.addLine(to: CGPoint(x: 14.8, y: 13.5))
                play.closeSubpath()
                ctx.fill(play, with: .color(.white))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "🍅 ×3" chip.
struct TomatoCount: View {
    var count: Int
    var textColor: Color
    var suffix: String = ""

    var body: some View {
        HStack(spacing: 3) {
            TomatoIcon(size: 13)
            Text("×\(count)\(suffix)").font(.rounded(11, .black)).foregroundStyle(textColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) focus session\(count == 1 ? "" : "s")\(suffix)")
    }
}

/// The card at the top of Today while a focus session or break is going.
struct FocusCard: View {
    @Environment(FocusController.self) private var focus
    @Environment(TodoStore.self) private var store
    var theme: Theme

    private var phase: PomodoroPhase { focus.timer.phase }
    private var fill: Color { phase.isBreak ? Theme.lime : Theme.tomato }

    private var label: String {
        let s = focus.settings
        switch phase {
        case .focus:
            let round = min(focus.timer.completedFocusCount + 1, s.longBreakEvery)
            let state = focus.timer.isRunning ? "FOCUS" : (focus.remaining >= Double(s.focusMinutes) * s.secondsPerMinute ? "READY" : "PAUSED")
            return "\(state) · \(round) OF \(s.longBreakEvery)"
        case .shortBreak: return focus.timer.isRunning ? "BREAK · STRETCH" : "BREAK · READY"
        case .longBreak: return focus.timer.isRunning ? "LONG BREAK · EARNED IT" : "LONG BREAK · READY"
        case .idle: return ""
        }
    }

    private var taskLine: String {
        let title = focus.task?.title
        if phase == .focus { return title.map { "on: \($0)" } ?? "free focus, no to-do" }
        return title.map { "next: back to \($0)" } ?? "next: another focus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.rounded(12, .black))
                    .tracking(1.1)
                    .lineLimit(1)
                Spacer(minLength: 6)
                TomatoCount(count: store.pomodorosToday, textColor: Theme.ink, suffix: " today")
                    .padding(.leading, 5)
                    .padding(.trailing, 8)
                    .padding(.vertical, 1.5)
                    .sticker(.white, line: theme.line, radius: 99, lineWidth: 2)
                    .rotationEffect(.degrees(2))
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(focus.clock)
                        .font(.rounded(44, .black))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(taskLine)
                        .font(.rounded(13, .heavy))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    control(focus.timer.isRunning ? "pause.fill" : "play.fill",
                            label: focus.timer.isRunning ? "Pause" : "Start", shadow: true, action: focus.togglePause)
                    control("forward.end.fill", label: "Skip to next phase", action: focus.skip)
                    control("stop.fill", label: "Stop session", action: focus.stop)
                }
            }

            ZStack(alignment: .leading) {
                Capsule().fill(.white)
                GeometryReader { geo in
                    Rectangle().fill(Theme.ink).frame(width: geo.size.width * focus.progress)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(theme.line, lineWidth: 2))
            .animation(.linear(duration: 0.9), value: focus.progress)

            if let task = focus.askDoneTask {
                VStack(alignment: .leading, spacing: 8) {
                    Text("nice! tomato earned. is \u{201C}\(task.title)\u{201D} done?")
                        .font(.rounded(14, .black))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { focus.answerDone(true) }
                        } label: {
                            Label("done", systemImage: "checkmark")
                                .labelStyle(TightLabel())
                                .font(.rounded(14, .black))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .sticker(Theme.pink, line: theme.line, shadow: theme.shadow, radius: 11, offset: 2)
                        }
                        .buttonStyle(PressableStyle())
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { focus.answerDone(false) }
                        } label: {
                            Text("keep going")
                                .font(.rounded(14, .black))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .sticker(.white, line: theme.line, radius: 11)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .sticker(.white, line: theme.line, radius: 14)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .sticker(fill, line: theme.line, shadow: theme.shadow, radius: 18)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: phase)
    }

    private func control(_ icon: String, label: String, shadow: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .sticker(.white, line: theme.line, shadow: shadow ? theme.shadow : nil, radius: 11, offset: 2)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// Focus mode on/off plus timings, as a sheet.
struct FocusSettingsView: View {
    @Environment(FocusController.self) private var focus
    var theme: Theme
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("focus mode")
                    .font(.rounded(22, .black))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(theme.text)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }

            HStack(spacing: 12) {
                TomatoIcon(size: 30, fill: .white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("pomodoro timer").font(.rounded(15, .black))
                    Text("work in sprints, earn a tomato per to-do. off by default")
                        .font(.rounded(12, .bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Focus mode", isOn: Binding(get: { focus.isEnabled }, set: { focus.setEnabled($0) }))
                    .toggleStyle(StickerToggleStyle(onColor: Theme.ink))
                    .labelsHidden()
            }
            .foregroundStyle(Theme.ink)
            .padding(12)
            .sticker(Theme.tomato, line: theme.line)

            Group {
                // Plain stacks, not a lazy grid: lazy cells are created after the sheet appears
                // and so skip its slide-in transition.
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        stepper("FOCUS", value: \.focusMinutes, unit: "min", range: PomodoroSettings.focusRange, step: 5)
                        stepper("SHORT BREAK", value: \.shortBreakMinutes, unit: "min", range: PomodoroSettings.shortBreakRange, step: 1)
                    }
                    HStack(spacing: 8) {
                        stepper("LONG BREAK", value: \.longBreakMinutes, unit: "min", range: PomodoroSettings.longBreakRange, step: 5)
                        stepper("LONG BREAK EVERY", value: \.longBreakEvery, unit: "rounds", range: PomodoroSettings.longBreakEveryRange, step: 1)
                    }
                }

                VStack(spacing: 0) {
                    toggle("auto-start breaks", \.autoStartBreaks)
                    toggle("auto-start next focus", \.autoStartFocus)
                    toggle("sound", \.sound)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .sticker(theme.bg, line: theme.line, radius: 14, lineWidth: 2)
            }
            .disabled(!focus.isEnabled)
            .opacity(focus.isEnabled ? 1 : 0.45)

            Text(focus.notificationsDenied
                 ? "notifications are off for Tver Ka: allow them in System Settings › Notifications. the chime still plays."
                 : "a notification and a little chime when each phase ends")
                .font(.rounded(12, .heavy))
                .foregroundStyle(focus.notificationsDenied ? Theme.danger : theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 22, offset: 4)
    }

    private func stepper(
        _ title: String, value: WritableKeyPath<PomodoroSettings, Int>, unit: String,
        range: ClosedRange<Int>, step: Int
    ) -> some View {
        let current = focus.settings[keyPath: value]
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rounded(11, .black))
                .tracking(0.8)
                .foregroundStyle(theme.sub)
                .lineLimit(1)
            HStack {
                stepButton("minus", label: "Decrease \(title.lowercased())", enabled: current > range.lowerBound) {
                    change(value, to: max(range.lowerBound, current - step))
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(current)").font(.rounded(16, .black))
                    Text(unit).font(.rounded(10, .heavy))
                }
                .foregroundStyle(theme.text)
                .lineLimit(1)
                Spacer(minLength: 0)
                stepButton("plus", label: "Increase \(title.lowercased())", enabled: current < range.upperBound) {
                    change(value, to: min(range.upperBound, current + step))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .sticker(theme.bg, line: theme.line, radius: 14, lineWidth: 2)
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(theme.text)
                .frame(width: 28, height: 28)
                .sticker(theme.card, line: theme.line, radius: 9, lineWidth: 2)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private func toggle(_ title: String, _ key: WritableKeyPath<PomodoroSettings, Bool>) -> some View {
        HStack {
            Text(title).font(.rounded(14, .heavy)).foregroundStyle(theme.text)
            Spacer()
            Toggle(title, isOn: Binding(
                get: { focus.settings[keyPath: key] },
                set: { change(key, to: $0) }))
                .toggleStyle(StickerToggleStyle(onColor: Theme.tomato))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .frame(height: 38)
    }

    private func change<V>(_ key: WritableKeyPath<PomodoroSettings, V>, to value: V) {
        var s = focus.settings
        s[keyPath: key] = value
        focus.update(s)
    }
}
