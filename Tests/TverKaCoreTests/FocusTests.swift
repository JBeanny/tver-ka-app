import Foundation
import Testing
@testable import TverKaCore

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
func after(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

@Suite struct PomodoroSettingsTests {
    @Test func defaultsAreClassicAndOff() {
        let s = PomodoroSettings()
        #expect(!s.enabled)
        #expect(s.focusMinutes == 25 && s.shortBreakMinutes == 5 && s.longBreakMinutes == 15 && s.longBreakEvery == 4)
        #expect(s.autoStartBreaks && !s.autoStartFocus && s.sound)
    }

    @Test func valuesAreClamped() {
        var s = PomodoroSettings()
        s.focusMinutes = 500
        s.shortBreakMinutes = 0
        s.longBreakMinutes = -3
        s.longBreakEvery = 1
        let c = s.clamped()
        #expect(c.focusMinutes == 90 && c.shortBreakMinutes == 1 && c.longBreakMinutes == 5 && c.longBreakEvery == 2)
    }

    @Test func timeScaleIsNotPersisted() throws {
        var s = PomodoroSettings()
        s.secondsPerMinute = 1
        let back = try JSONDecoder().decode(PomodoroSettings.self, from: JSONEncoder().encode(s))
        #expect(back.secondsPerMinute == 60)
    }
}

@Suite struct PomodoroTimerTests {
    let settings = PomodoroSettings()
    let task = UUID()

    @Test func startRunsAFocusSessionOnATask() {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        #expect(timer.phase == .focus)
        #expect(timer.isRunning)
        #expect(timer.taskID == task)
        #expect(timer.remaining(now: after(60)) == 24 * 60)
    }

    @Test func finishingFocusEmitsATomatoAndAutoStartsTheBreak() {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        #expect(timer.tick(now: after(10), settings: settings) == nil)

        let event = timer.tick(now: after(25 * 60), settings: settings)

        #expect(event == .focusCompleted(task: task, minutes: 25))
        #expect(timer.phase == .shortBreak)
        #expect(timer.isRunning)
        #expect(timer.remaining(now: after(25 * 60)) == 5 * 60)
    }

    @Test func breakWaitsForYouWhenAutoStartIsOff() {
        var s = settings
        s.autoStartBreaks = false
        var timer = PomodoroTimer()
        timer.start(task: nil, settings: s, now: t0)
        _ = timer.tick(now: after(25 * 60), settings: s)
        #expect(timer.phase == .shortBreak)
        #expect(timer.isPaused)
        #expect(timer.remaining(now: after(99_999)) == 5 * 60)
    }

    @Test func everyFourthFocusEarnsALongBreakThenTheCycleResets() {
        var timer = PomodoroTimer()
        var now = t0
        timer.start(task: nil, settings: settings, now: now)
        var breaks: [PomodoroPhase] = []
        for _ in 0..<5 {
            now = now.addingTimeInterval(timer.remaining(now: now))
            _ = timer.tick(now: now, settings: settings)       // focus done → break
            breaks.append(timer.phase)
            now = now.addingTimeInterval(timer.remaining(now: now))
            let event = timer.tick(now: now, settings: settings) // break done → focus (waiting)
            #expect(event == .breakCompleted)
            #expect(timer.phase == .focus && timer.isPaused)
            timer.resume(now: now)
        }
        #expect(breaks == [.shortBreak, .shortBreak, .shortBreak, .longBreak, .shortBreak])
    }

    @Test func pauseAndResumeKeepTheRemainingTime() {
        var timer = PomodoroTimer()
        timer.start(task: nil, settings: settings, now: t0)
        timer.pause(now: after(600))
        #expect(timer.isPaused)
        #expect(timer.remaining(now: after(5_000)) == 15 * 60)
        #expect(timer.tick(now: after(99_999), settings: settings) == nil)
        timer.resume(now: after(5_000))
        #expect(timer.remaining(now: after(5_000 + 60)) == 14 * 60)
    }

    @Test func skippingFocusGoesToABreakWithoutATomato() {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        timer.skip(settings: settings, now: after(60))
        #expect(timer.phase == .shortBreak)
        #expect(timer.completedFocusCount == 0)
        timer.skip(settings: settings, now: after(120))
        #expect(timer.phase == .focus)
        #expect(timer.taskID == task)
    }

    @Test func stopResetsEverything() {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        timer.stop()
        #expect(timer == PomodoroTimer())
        #expect(timer.phase == .idle && !timer.isRunning && !timer.isPaused)
    }

    @Test func longSleepCompletesExactlyOnePhase() {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        let wake = after(3 * 60 * 60)
        #expect(timer.tick(now: wake, settings: settings) == .focusCompleted(task: task, minutes: 25))
        #expect(timer.phase == .shortBreak)
        #expect(timer.remaining(now: wake) == 5 * 60)
        #expect(timer.tick(now: wake, settings: settings) == nil)
    }

    @Test func timeScaleShrinksMinutesForTesting() {
        var s = settings
        s.secondsPerMinute = 1
        var timer = PomodoroTimer()
        timer.start(task: nil, settings: s, now: t0)
        #expect(timer.tick(now: after(25), settings: s) == .focusCompleted(task: nil, minutes: 25))
    }

    @Test func runningSessionSurvivesEncoding() throws {
        var timer = PomodoroTimer()
        timer.start(task: task, settings: settings, now: t0)
        let back = try JSONDecoder().decode(PomodoroTimer.self, from: JSONEncoder().encode(timer))
        #expect(back == timer)
        #expect(back.remaining(now: after(60)) == 24 * 60)
    }

    @Test func progressGoesFromZeroToOne() {
        var timer = PomodoroTimer()
        timer.start(task: nil, settings: settings, now: t0)
        #expect(timer.progress(now: t0) == 0)
        #expect(abs(timer.progress(now: after(750)) - 0.5) < 0.0001)
    }
}

@MainActor
@Suite struct FocusStoreTests {
    func store(_ file: URL = tempDir().appendingPathComponent("todos.json"), _ now: Date = day(2026, 11, 3)) -> TodoStore {
        TodoStore(fileURL: file, calendar: utc, now: { now })
    }

    @Test func recordingATomatoCountsOnTheTaskAndToday() {
        let s = store()
        s.add("stats set")
        let id = s.todos[0].id
        s.recordPomodoro(todoID: id, minutes: 25)
        s.recordPomodoro(todoID: nil, minutes: 25)
        #expect(s.todo(id)?.pomodoros == 1)
        #expect(s.pomodorosToday == 2)
    }

    @Test func tomatoesPersistAndSurviveRollover() {
        let file = tempDir().appendingPathComponent("todos.json")
        let first = store(file, day(2026, 11, 2))
        first.add("stats set")
        first.recordPomodoro(todoID: first.todos[0].id, minutes: 25)

        let next = store(file, day(2026, 11, 3))
        #expect(next.todos[0].pomodoros == 1)
        #expect(next.todos[0].rollCount == 1)
        #expect(next.pomodorosToday == 0)
    }

    @Test func oldFilesWithoutTomatoesStillLoad() throws {
        let file = tempDir().appendingPathComponent("todos.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode([todo("legacy", due: day(2026, 11, 3))])
        var json = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        json[0].removeValue(forKey: "pomodoros")
        data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: file)

        let s = store(file)
        #expect(s.todos.first?.pomodoros == 0)
        #expect(s.pomodorosToday == 0)
    }

    @Test func focusLogKeepsSixtyDays() {
        let file = tempDir().appendingPathComponent("todos.json")
        store(file, day(2026, 8, 1)).recordPomodoro(todoID: nil, minutes: 25)
        let later = store(file, day(2026, 11, 3))
        later.recordPomodoro(todoID: nil, minutes: 25)
        #expect(later.focusLog.count == 1)
    }

    @Test func digestShowsTomatoesOnlyWhenEarned() {
        let s = store()
        s.digestURL = tempDir().appendingPathComponent("Today.md")
        s.add("stats set")
        s.add("gym")
        s.recordPomodoro(todoID: s.todos[0].id, minutes: 25)
        let md = try! String(contentsOf: s.digestURL!, encoding: .utf8)
        #expect(md.contains("- stats set · personal · 🍅×1"))
        #expect(md.contains("- gym · personal\n"))
    }
}
