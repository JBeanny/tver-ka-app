import SwiftUI
import TverKaCore

struct DoneDrawerView: View {
    @Environment(TodoStore.self) private var store
    var theme: Theme
    var back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                StickerIconButton(systemImage: "chevron.left", label: "Back to today", theme: theme, action: back)
                VStack(alignment: .leading, spacing: 1) {
                    Text("the done pile")
                        .font(.rounded(22, .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 5) {
                        if store.showingAll {
                            AllProjectsDot(line: theme.line, size: 10)
                        } else {
                            ProjectDot(color: store.activeProject.color, line: theme.line, size: 10)
                        }
                        Text(store.showingAll ? "all projects" : store.activeProject.name)
                            .font(.rounded(12, .heavy))
                            .foregroundStyle(theme.sub)
                            .lineLimit(1)
                    }
                }
                    .foregroundStyle(theme.text)
                Spacer()
                StickerBadge(
                    text: "\(store.doneThisWeekCount) this week", icon: "checkmark", fill: Theme.blue,
                    textColor: .white, line: theme.line, tilt: 3, size: 13, capsule: true)
            }

            HStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 22, weight: .bold))
                Text(banner)
                    .font(.rounded(14, .heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(Theme.lime, line: theme.line, shadow: theme.shadow)

            if store.doneDays.isEmpty {
                Spacer()
                Text("nothing here yet. go check something off.")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(theme.sub)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(store.doneDays) { day in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(label(for: day.day).uppercased())
                                    .font(.rounded(12, .black))
                                    .tracking(1.2)
                                    .foregroundStyle(theme.sub)
                                ForEach(day.items) { DoneRow(todo: $0, theme: theme) }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
                .padding(.horizontal, -6)
            }
        }
        .padding(18)
    }

    private var banner: String {
        let comeback = store.rolledDoneThisWeekCount
        if comeback > 0 {
            return "you cleared \(comeback) carried-over to-do\(comeback == 1 ? "" : "s") this week. the comeback is real."
        }
        return "every check counts. keep stacking."
    }

    private func label(for day: Date) -> String {
        let cal = store.calendar
        if cal.isDate(day, inSameDayAs: store.currentDay) { return "today" }
        if let y = cal.date(byAdding: .day, value: -1, to: store.currentDay), cal.isDate(day, inSameDayAs: y) {
            return "yesterday · \(day.formatted(.dateTime.weekday(.abbreviated)))"
        }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

private struct DoneRow: View {
    @Environment(TodoStore.self) private var store
    var todo: Todo
    var theme: Theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.lime))
                .overlay(Circle().strokeBorder(theme.line, lineWidth: 2.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.rounded(14, .bold))
                    .foregroundStyle(theme.sub)
                    .strikethrough(true, color: theme.sub)
                if store.showingAll {
                    ProjectTag(project: store.project(for: todo), line: theme.line, textColor: theme.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if todo.rollCount > 0 {
                StickerBadge(text: "beat it after ×\(todo.rollCount)", fill: Theme.butter, tilt: -3, size: 10)
            }
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.toggleDone(todo.id) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(theme.sub)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo, move \(todo.title) back to today")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .sticker(theme.card, line: theme.line, radius: 14, lineWidth: 2)
    }
}
