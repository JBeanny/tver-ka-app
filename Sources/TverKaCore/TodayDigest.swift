import Foundation

/// A plain Markdown snapshot of what's open today, across all projects.
/// Written to iCloud Drive so the iPhone (Files app or a Shortcut) can read it.
public enum TodayDigest {
    public static func render(todos: [Todo], projects: [Project], now: Date, calendar: Calendar) -> String {
        let format = DateFormatter()
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "EEE, MMM d"
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"

        let names = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        func line(_ t: Todo, extra: String? = nil) -> String {
            let tomatoes = t.pomodoros > 0 ? "🍅×\(t.pomodoros)" : nil
            return ["- \(t.title)", t.projectID.flatMap { names[$0] }, extra, tomatoes]
                .compactMap { $0 }.joined(separator: " · ")
        }
        func items(_ status: TodoStatus) -> [Todo] {
            todos.filter { $0.status(now: now, calendar: calendar) == status }
        }

        var out = ["# Tver Ka · \(format.string(from: now))", "_updated \(time.string(from: now))_", ""]
        let priority = items(.priority).sorted { $0.rollCount > $1.rollCount }
        let today = items(.today)
        let missed = items(.missed)

        if priority.isEmpty && today.isEmpty && missed.isEmpty {
            out.append("all clear, bestie ✨")
        }
        if !priority.isEmpty {
            out.append("## Priority")
            out += priority.map { line($0, extra: $0.rollCount > 0 ? "rolled ×\($0.rollCount)" : nil) }
            out.append("")
        }
        if !today.isEmpty {
            out.append("## Today")
            out += today.map { line($0) }
            out.append("")
        }
        if !missed.isEmpty {
            out.append("## Missed")
            out += missed.map { line($0, extra: "was due \(format.string(from: $0.dueDate))") }
            out.append("")
        }
        return out.joined(separator: "\n") + "\n"
    }
}
