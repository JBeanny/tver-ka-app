import SwiftUI
import TverKaCore

struct TodoRow: View {
    @Environment(TodoStore.self) private var store
    @Environment(FocusController.self) private var focus
    var todo: Todo
    var theme: Theme
    var edit: () -> Void

    @State private var checking = false

    private var fill: Color { todo.isPriority ? Theme.butter : theme.card }
    private var textColor: Color { todo.isPriority ? Theme.ink : theme.text }
    private var metaColor: Color { todo.isPriority ? Color(hex: 0x4A4033) : theme.sub }
    private var isFocusing: Bool {
        focus.isActive && focus.timer.phase == .focus && focus.timer.taskID == todo.id
    }
    private var showsTomatoes: Bool { focus.isEnabled && todo.pomodoros > 0 }

    var body: some View {
        HStack(spacing: 10) {
            checkButton
            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(textColor)
                    .strikethrough(checking, color: textColor)
                    .fixedSize(horizontal: false, vertical: true)
                let showsRoll = todo.rollCount > 0 || (todo.isPriority && todo.autoRoll)
                if showsRoll || store.showingAll || showsTomatoes || isFocusing {
                    HStack(spacing: 6) {
                        if store.showingAll {
                            ProjectTag(project: store.project(for: todo), line: theme.line, textColor: metaColor)
                        }
                        if todo.rollCount > 0 {
                            StickerBadge(text: "rolled ×\(todo.rollCount)", fill: Theme.blue, textColor: .white, tilt: 2)
                        }
                        if showsTomatoes {
                            TomatoCount(count: todo.pomodoros, textColor: metaColor)
                        }
                        if isFocusing {
                            Text("focusing…")
                                .font(.rounded(11, .black))
                                .foregroundStyle(todo.isPriority ? Theme.danger : Theme.tomato)
                        }
                        if showsRoll && !store.showingAll && !showsTomatoes && !isFocusing {
                            Label(todo.autoRoll ? "auto-roll on" : "auto-roll off", systemImage: "repeat")
                                .font(.rounded(11, .heavy))
                                .foregroundStyle(metaColor)
                                .labelStyle(TightLabel())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: edit)
            if focus.isEnabled && !isFocusing {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { focus.start(task: todo.id) }
                } label: {
                    TomatoIcon(size: 18, showsPlay: true)
                        .frame(width: 30, height: 30)
                        .sticker(todo.isPriority ? .white : theme.bg, line: todo.isPriority ? Theme.ink : theme.line,
                                 radius: 9, lineWidth: 2)
                }
                .buttonStyle(PressableStyle())
                .help("Focus on this to-do")
                .accessibilityLabel("Focus on \(todo.title)")
            }
            Button(action: edit) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(todo.isPriority ? Theme.ink : theme.sub)
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Task options")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, todo.isPriority ? 8 : 4)
        .sticker(fill, line: theme.line, shadow: theme.shadow)
        .overlay {
            if isFocusing {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.tomato, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .padding(-5)
            }
        }
        .scaleEffect(checking ? 0.97 : 1)
        .opacity(checking ? 0.6 : 1)
        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
    }

    private var checkButton: some View {
        Button {
            guard !checking else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { checking = true }
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { store.toggleDone(todo.id) }
            }
        } label: {
            ZStack {
                Circle().fill(checking ? Theme.lime : (todo.isPriority ? .white : theme.bg))
                Circle().strokeBorder(todo.isPriority ? Theme.ink : theme.line, lineWidth: 2.5)
                if checking {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: 28, height: 28)
            .scaleEffect(checking ? 1.2 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(todo.title) done")
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

struct MissedCard: View {
    @Environment(TodoStore.self) private var store
    var todo: Todo
    var theme: Theme

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(theme.missedText)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.bg))
                    .overlay(Circle().strokeBorder(theme.missedLine, lineWidth: 2.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(todo.title).font(.rounded(15, .heavy)).foregroundStyle(theme.missedText)
                    HStack(spacing: 6) {
                        Text("was due \(todo.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                            .font(.rounded(12, .bold))
                            .foregroundStyle(theme.sub)
                        if store.showingAll {
                            ProjectTag(project: store.project(for: todo), line: theme.missedLine, textColor: theme.sub)
                        }
                    }
                }
                Spacer()
                Image(systemName: "repeat")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(theme.missedLine)
                    .overlay(Rectangle().fill(theme.missedLine).frame(width: 20, height: 2).rotationEffect(.degrees(45)))
                    .accessibilityLabel("Auto-roll off")
            }
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.bringToToday(todo.id) }
                } label: {
                    Label("bring to today", systemImage: "arrow.right")
                        .labelStyle(TightLabel())
                        .font(.rounded(13, .black))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 12, offset: 2)
                }
                .buttonStyle(PressableStyle())
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.delete(todo.id) }
                } label: {
                    Text("let it go")
                        .font(.rounded(13, .black))
                        .foregroundStyle(theme.missedText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .sticker(.clear, line: theme.missedLine, radius: 12)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(12)
        .sticker(theme.missedFill, line: theme.missedLine, dashed: true)
    }
}
