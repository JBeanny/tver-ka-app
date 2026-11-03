import Foundation

/// Per-Mac Focus mode settings. Off by default.
public struct PomodoroSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var focusMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 15
    /// A long break comes after this many focus sessions.
    public var longBreakEvery = 4
    public var autoStartBreaks = true
    public var autoStartFocus = false
    public var sound = true
    /// 60 normally; lowered only for testing (e.g. 1 makes every minute a second). Never saved.
    public var secondsPerMinute: Double = 60

    public init() {}

    enum CodingKeys: String, CodingKey {
        case enabled, focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakEvery
        case autoStartBreaks, autoStartFocus, sound
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PomodoroSettings()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        longBreakEvery = try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? d.longBreakEvery
        autoStartBreaks = try c.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? d.autoStartBreaks
        autoStartFocus = try c.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? d.autoStartFocus
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
    }

    public static let focusRange = 5...90
    public static let shortBreakRange = 1...30
    public static let longBreakRange = 5...60
    public static let longBreakEveryRange = 2...8

    public func clamped() -> PomodoroSettings {
        var s = self
        s.focusMinutes = min(max(focusMinutes, Self.focusRange.lowerBound), Self.focusRange.upperBound)
        s.shortBreakMinutes = min(max(shortBreakMinutes, Self.shortBreakRange.lowerBound), Self.shortBreakRange.upperBound)
        s.longBreakMinutes = min(max(longBreakMinutes, Self.longBreakRange.lowerBound), Self.longBreakRange.upperBound)
        s.longBreakEvery = min(max(longBreakEvery, Self.longBreakEveryRange.lowerBound), Self.longBreakEveryRange.upperBound)
        return s
    }

    public func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .idle: 0
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    func duration(for phase: PomodoroPhase) -> TimeInterval {
        Double(minutes(for: phase)) * secondsPerMinute
    }
}

public enum PomodoroPhase: String, Codable, Sendable {
    case idle, focus, shortBreak, longBreak
    public var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

public enum PomodoroEvent: Equatable, Sendable {
    case focusCompleted(task: UUID?, minutes: Int)
    case breakCompleted
}

/// The Pomodoro state machine. Time is wall-clock based (`endsAt`), so sleep never makes it drift.
/// A phase is either running (has `endsAt`) or waiting/paused (has `pausedRemaining`).
public struct PomodoroTimer: Codable, Equatable, Sendable {
    public private(set) var phase: PomodoroPhase = .idle
    public private(set) var endsAt: Date?
    public private(set) var pausedRemaining: TimeInterval?
    /// Full length of the current phase, for progress.
    public private(set) var duration: TimeInterval = 0
    public private(set) var taskID: UUID?
    /// Focus sessions finished since the last long break.
    public private(set) var completedFocusCount = 0

    public init() {}

    public var isActive: Bool { phase != .idle }
    public var isRunning: Bool { endsAt != nil }
    public var isPaused: Bool { phase != .idle && endsAt == nil }

    public func remaining(now: Date) -> TimeInterval {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return pausedRemaining ?? 0
    }

    public func progress(now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(now: now) / duration))
    }

    /// Starts a focus session, optionally on a to-do.
    public mutating func start(task: UUID?, settings: PomodoroSettings, now: Date) {
        taskID = task
        begin(.focus, running: true, settings: settings, now: now)
    }

    public mutating func pause(now: Date) {
        guard let endsAt else { return }
        pausedRemaining = max(0, endsAt.timeIntervalSince(now))
        self.endsAt = nil
    }

    public mutating func resume(now: Date) {
        guard isPaused, let left = pausedRemaining else { return }
        endsAt = now.addingTimeInterval(left)
        pausedRemaining = nil
    }

    /// Jumps to the next phase, started. Skipping focus earns no tomato.
    public mutating func skip(settings: PomodoroSettings, now: Date) {
        guard isActive else { return }
        begin(phase == .focus ? breakAfterFocus(settings, counting: false) : .focus, running: true, settings: settings, now: now)
    }

    public mutating func stop() {
        self = PomodoroTimer()
    }

    /// Call often. When the running phase has ended, moves on and reports what finished.
    public mutating func tick(now: Date, settings: PomodoroSettings) -> PomodoroEvent? {
        guard let endsAt, now >= endsAt else { return nil }
        switch phase {
        case .focus:
            completedFocusCount += 1
            let event = PomodoroEvent.focusCompleted(task: taskID, minutes: settings.focusMinutes)
            begin(breakAfterFocus(settings, counting: true), running: settings.autoStartBreaks, settings: settings, now: now)
            return event
        case .shortBreak, .longBreak:
            if phase == .longBreak { completedFocusCount = 0 }
            begin(.focus, running: settings.autoStartFocus, settings: settings, now: now)
            return .breakCompleted
        case .idle:
            return nil
        }
    }

    private func breakAfterFocus(_ settings: PomodoroSettings, counting: Bool) -> PomodoroPhase {
        let count = completedFocusCount
        return counting && count > 0 && count % settings.longBreakEvery == 0 ? .longBreak : .shortBreak
    }

    private mutating func begin(_ next: PomodoroPhase, running: Bool, settings: PomodoroSettings, now: Date) {
        phase = next
        duration = settings.duration(for: next)
        if running {
            endsAt = now.addingTimeInterval(duration)
            pausedRemaining = nil
        } else {
            endsAt = nil
            pausedRemaining = duration
        }
    }
}

/// One finished focus session, kept in the data file (and synced) for "tomatoes today".
public struct FocusEntry: Codable, Equatable, Sendable {
    public var date: Date
    public var minutes: Int
    public var todoID: UUID?
}
