import Foundation
import Testing
@testable import TverKaCore

let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

func todo(_ title: String = "t", due: Date, autoRoll: Bool = true, done: Bool = false) -> Todo {
    var t = Todo(title: title, createdAt: due, dueDate: utc.startOfDay(for: due), autoRoll: autoRoll)
    if done { t.isDone = true; t.doneAt = due }
    return t
}

@Suite struct RolloverTests {
    @Test func unfinishedAutoRollTaskMovesToTodayAsPriority() {
        let t = todo(due: day(2026, 10, 31))
        let out = Rollover.apply(to: [t], now: day(2026, 11, 1), calendar: utc)
        #expect(out[0].dueDate == utc.startOfDay(for: day(2026, 11, 1)))
        #expect(out[0].isPriority)
        #expect(out[0].rollCount == 1)
    }

    @Test func autoRollOffStaysOnOriginalDayAndIsMissed() {
        let t = todo(due: day(2026, 10, 31), autoRoll: false)
        let now = day(2026, 11, 1)
        let out = Rollover.apply(to: [t], now: now, calendar: utc)
        #expect(out[0] == t)
        #expect(out[0].status(now: now, calendar: utc) == .missed)
    }

    @Test func doneTasksNeverRoll() {
        let t = todo(due: day(2026, 10, 31), done: true)
        let out = Rollover.apply(to: [t], now: day(2026, 11, 1), calendar: utc)
        #expect(out[0] == t)
    }

    @Test func todaysTasksAreUntouched() {
        let t = todo(due: day(2026, 11, 1, 8))
        let out = Rollover.apply(to: [t], now: day(2026, 11, 1, 23), calendar: utc)
        #expect(out[0] == t)
    }

    @Test func rollCountAccumulatesAcrossDays() {
        var t = todo(due: day(2026, 10, 30))
        t = Rollover.apply(to: [t], now: day(2026, 10, 31), calendar: utc)[0]
        t = Rollover.apply(to: [t], now: day(2026, 11, 1), calendar: utc)[0]
        #expect(t.rollCount == 2)
        // Running again the same day is a no-op.
        t = Rollover.apply(to: [t], now: day(2026, 11, 1, 22), calendar: utc)[0]
        #expect(t.rollCount == 2)
    }

    @Test func skippedDaysWhileAppClosedAllCount() {
        let t = todo(due: day(2026, 10, 28))
        let out = Rollover.apply(to: [t], now: day(2026, 11, 1), calendar: utc)
        #expect(out[0].rollCount == 4)
    }

    @Test func midnightBoundary() {
        let t = todo(due: day(2026, 10, 31, 23))
        let justBefore = utc.date(byAdding: .second, value: -1, to: utc.startOfDay(for: day(2026, 11, 1)))!
        #expect(Rollover.apply(to: [t], now: justBefore, calendar: utc)[0].rollCount == 0)
        let midnight = utc.startOfDay(for: day(2026, 11, 1))
        #expect(Rollover.apply(to: [t], now: midnight, calendar: utc)[0].rollCount == 1)
    }

    @Test func statusClassification() {
        let now = day(2026, 11, 1)
        var p = todo(due: now); p.isPriority = true
        #expect(p.status(now: now, calendar: utc) == .priority)
        #expect(todo(due: now).status(now: now, calendar: utc) == .today)
        #expect(todo(due: now, done: true).status(now: now, calendar: utc) == .done)
        #expect(todo(due: day(2026, 11, 2)).status(now: now, calendar: utc) == .upcoming)
    }
}

@Suite struct StatsTests {
    @Test func streakCountsConsecutiveDaysEndingToday() {
        let items = [
            todo(due: day(2026, 11, 1), done: true),
            todo(due: day(2026, 10, 31), done: true),
            todo(due: day(2026, 10, 30), done: true),
            todo(due: day(2026, 10, 28), done: true),
        ]
        #expect(Stats.streak(items, now: day(2026, 11, 1), calendar: utc) == 3)
    }

    @Test func streakSurvivesIfNothingDoneYetToday() {
        let items = [todo(due: day(2026, 10, 31), done: true), todo(due: day(2026, 10, 30), done: true)]
        #expect(Stats.streak(items, now: day(2026, 11, 1), calendar: utc) == 2)
    }

    @Test func streakBreaksAfterAMissedDay() {
        let items = [todo(due: day(2026, 10, 30), done: true)]
        #expect(Stats.streak(items, now: day(2026, 11, 1), calendar: utc) == 0)
    }

    @Test func doneGroupedByDayNewestFirst() {
        let items = [
            todo("a", due: day(2026, 10, 31, 9), done: true),
            todo("b", due: day(2026, 11, 1, 9), done: true),
            todo("c", due: day(2026, 11, 1, 15), done: true),
            todo("open", due: day(2026, 11, 1)),
        ]
        let groups = Stats.doneByDay(items, calendar: utc)
        #expect(groups.map { $0.items.map(\.title) } == [["c", "b"], ["a"]])
    }
}
