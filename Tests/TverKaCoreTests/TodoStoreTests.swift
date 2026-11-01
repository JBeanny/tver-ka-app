import Foundation
import Testing
@testable import TverKaCore

@MainActor
@Suite struct TodoStoreTests {
    func makeStore(file: URL, now: @escaping @Sendable () -> Date) -> TodoStore {
        TodoStore(fileURL: file, calendar: utc, now: now)
    }

    func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tverka-\(UUID().uuidString).json")
    }

    @Test func addedTodoLandsOnToday() {
        let store = makeStore(file: tempFile()) { day(2026, 11, 1) }
        store.add("buy oat milk")
        #expect(store.todayItems.map(\.title) == ["buy oat milk"])
        #expect(store.todos[0].autoRoll)
    }

    @Test func blankTitlesAreIgnored() {
        let store = makeStore(file: tempFile()) { day(2026, 11, 1) }
        store.add("   ")
        #expect(store.todos.isEmpty)
    }

    @Test func persistsAndRollsOverOnReload() {
        let file = tempFile()
        let first = makeStore(file: file) { day(2026, 10, 31) }
        first.add("stats homework")
        first.add("concert tix")
        first.update(first.todos[1].id, autoRoll: false)

        let next = makeStore(file: file) { day(2026, 11, 1) }
        #expect(next.priorityItems.map(\.title) == ["stats homework"])
        #expect(next.missedItems.map(\.title) == ["concert tix"])
    }

    @Test func undoFromDoneMovesBackToToday() {
        let file = tempFile()
        let first = makeStore(file: file) { day(2026, 10, 31) }
        first.add("laundry")
        first.toggleDone(first.todos[0].id)

        let next = makeStore(file: file) { day(2026, 11, 1) }
        next.toggleDone(next.todos[0].id)
        #expect(next.todayItems.map(\.title) == ["laundry"])
    }

    @Test func bringMissedToToday() {
        let file = tempFile()
        let first = makeStore(file: file) { day(2026, 10, 31) }
        first.add("concert tix")
        first.update(first.todos[0].id, autoRoll: false)

        let next = makeStore(file: file) { day(2026, 11, 1) }
        next.bringToToday(next.todos[0].id)
        #expect(next.missedItems.isEmpty)
        #expect(next.todayItems.map(\.title) == ["concert tix"])
    }
}
