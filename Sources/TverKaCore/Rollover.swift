import Foundation

public enum Rollover {
    /// Moves every unfinished, auto-roll to-do from a past day onto today and marks it priority.
    /// Each skipped day counts toward `rollCount`, so days the app was closed still count.
    /// To-dos with auto-roll off are left alone and read as `.missed`.
    public static func apply(to todos: [Todo], now: Date, calendar: Calendar) -> [Todo] {
        let today = calendar.startOfDay(for: now)
        return todos.map { todo in
            guard !todo.isDone, todo.autoRoll else { return todo }
            let due = calendar.startOfDay(for: todo.dueDate)
            guard due < today else { return todo }
            let skipped = calendar.dateComponents([.day], from: due, to: today).day ?? 1
            var rolled = todo
            rolled.dueDate = today
            rolled.isPriority = true
            rolled.rollCount += max(skipped, 1)
            return rolled
        }
    }
}

public enum Stats {
    public struct DoneDay: Identifiable, Sendable {
        public var day: Date
        public var items: [Todo]
        public var id: Date { day }
    }

    /// Consecutive days with at least one finished to-do, ending today
    /// (or yesterday, so the streak doesn't vanish before you've done anything today).
    public static func streak(_ todos: [Todo], now: Date, calendar: Calendar) -> Int {
        let days = Set(todos.compactMap { $0.doneAt.map { calendar.startOfDay(for: $0) } })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    public static func doneByDay(_ todos: [Todo], calendar: Calendar) -> [DoneDay] {
        let done = todos.filter { $0.isDone && $0.doneAt != nil }
        let grouped = Dictionary(grouping: done) { calendar.startOfDay(for: $0.doneAt!) }
        return grouped
            .map { DoneDay(day: $0.key, items: $0.value.sorted { $0.doneAt! > $1.doneAt! }) }
            .sorted { $0.day > $1.day }
    }
}
