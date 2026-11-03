import AppKit
import Observation
import TverKaCore
import UserNotifications

/// Runs Focus mode: the Pomodoro timer, tomatoes, sound and notifications. Settings and the running
/// session are per Mac (UserDefaults); tomatoes go into the synced data file through the store.
@MainActor
@Observable
final class FocusController {
    private static let settingsKey = "focusSettings"
    private static let timerKey = "focusTimer"

    private let store: TodoStore
    private(set) var settings: PomodoroSettings
    private(set) var timer: PomodoroTimer
    /// Ticks every second while running so the countdown redraws.
    private(set) var now = Date()
    /// After a focus session on a to-do: ask whether that to-do is done.
    private(set) var askDoneTaskID: Todo.ID?
    private(set) var notificationsDenied = false

    private var ticker: Timer?
    private let notifications = FocusNotifications()

    init(store: TodoStore) {
        self.store = store
        let defaults = SyncController.defaults
        var settings = defaults.data(forKey: Self.settingsKey)
            .flatMap { try? JSONDecoder().decode(PomodoroSettings.self, from: $0) } ?? PomodoroSettings()
        settings.secondsPerMinute = AppEnvironment.focusSecondsPerMinute
        self.settings = settings
        self.timer = defaults.data(forKey: Self.timerKey)
            .flatMap { try? JSONDecoder().decode(PomodoroTimer.self, from: $0) } ?? PomodoroTimer()
        notifications.onAction = { [weak self] action in self?.handle(action) }
        if !settings.enabled { timer.stop() }
        tick()
    }

    var isEnabled: Bool { settings.enabled }
    var isActive: Bool { settings.enabled && timer.isActive }
    var remaining: TimeInterval { timer.remaining(now: now) }
    var progress: Double { timer.progress(now: now) }

    var clock: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var task: Todo? { timer.taskID.flatMap(store.todo) }
    var askDoneTask: Todo? { askDoneTaskID.flatMap(store.todo).flatMap { $0.isDone ? nil : $0 } }

    // MARK: - Settings

    func setEnabled(_ on: Bool) {
        var s = settings
        s.enabled = on
        update(s)
        if on {
            notifications.requestPermission { [weak self] granted in self?.notificationsDenied = !granted }
        } else {
            stop()
        }
    }

    func update(_ new: PomodoroSettings) {
        var s = new.clamped()
        s.secondsPerMinute = settings.secondsPerMinute
        settings = s
        if let data = try? JSONEncoder().encode(s) { SyncController.defaults.set(data, forKey: Self.settingsKey) }
    }

    // MARK: - Controls

    func start(task: Todo.ID?) {
        guard settings.enabled else { return }
        askDoneTaskID = nil
        timer.start(task: task, settings: settings, now: Date())
        changed()
    }

    func togglePause() {
        if timer.isRunning { timer.pause(now: Date()) } else { timer.resume(now: Date()) }
        changed()
    }

    func skip() {
        timer.skip(settings: settings, now: Date())
        if timer.phase == .focus { askDoneTaskID = nil }
        changed()
    }

    func stop() {
        timer.stop()
        askDoneTaskID = nil
        notifications.clear()
        changed()
    }

    func answerDone(_ isDone: Bool) {
        if isDone, let id = askDoneTaskID, store.todo(id)?.isDone == false {
            store.toggleDone(id)
        }
        askDoneTaskID = nil
    }

    // MARK: - Ticking

    func tick() {
        now = Date()
        guard settings.enabled, let event = timer.tick(now: now, settings: settings) else {
            scheduleTicker()
            return
        }
        switch event {
        case .focusCompleted(let task, let minutes):
            store.recordPomodoro(todoID: task, minutes: minutes)
            askDoneTaskID = task
            let title = task.flatMap(store.todo)?.title
            notifications.post(
                title: "focus done 🍅",
                body: title.map { "one more tomato on “\($0)”. " + breakLine } ?? breakLine,
                category: task == nil ? FocusNotifications.focusDoneFree : FocusNotifications.focusDoneTask)
        case .breakCompleted:
            notifications.post(
                title: "break's over",
                body: timer.isRunning ? "back to it, you got this" : "ready when you are: start the next focus",
                category: FocusNotifications.breakDone)
        }
        if settings.sound { NSSound(named: "Glass")?.play() }
        changed()
    }

    private var breakLine: String {
        let minutes = settings.minutes(for: timer.phase)
        let kind = timer.phase == .longBreak ? "long break" : "break"
        return timer.isRunning ? "take \(minutes), \(kind) started." : "\(kind) ready when you are."
    }

    private func changed() {
        now = Date()
        if let data = try? JSONEncoder().encode(timer) { SyncController.defaults.set(data, forKey: Self.timerKey) }
        scheduleTicker()
    }

    /// A 1-second timer only while a phase is actually counting down.
    private func scheduleTicker() {
        let shouldRun = settings.enabled && timer.isRunning
        if shouldRun, ticker == nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(t, forMode: .common)
            ticker = t
        } else if !shouldRun {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func handle(_ action: String) {
        switch action {
        case FocusNotifications.markDone: answerDone(true)
        case FocusNotifications.startNext:
            if timer.isPaused { timer.resume(now: Date()) }
            changed()
        default: break
        }
    }

    // MARK: - Snapshot support

    func debugSet(timer: PomodoroTimer, askDone: Todo.ID? = nil, now: Date) {
        self.timer = timer
        self.askDoneTaskID = askDone
        self.now = now
    }
}

/// Wraps UNUserNotificationCenter: categories with quick actions, and routing taps back to the controller.
final class FocusNotifications: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let focusDoneTask = "TVERKA_FOCUS_DONE_TASK"
    static let focusDoneFree = "TVERKA_FOCUS_DONE"
    static let breakDone = "TVERKA_BREAK_DONE"
    static let markDone = "TVERKA_MARK_DONE"
    static let startNext = "TVERKA_START_NEXT"

    @MainActor var onAction: ((String) -> Void)?

    /// Notifications need a real app bundle; plain `swift run` builds simply skip them.
    private let center: UNUserNotificationCenter? =
        Bundle.main.bundleIdentifier == nil || AppEnvironment.snapshotDir != nil ? nil : .current()

    override init() {
        super.init()
        guard let center else { return }
        center.delegate = self
        let markDone = UNNotificationAction(identifier: Self.markDone, title: "Mark done ✓")
        let startBreak = UNNotificationAction(identifier: Self.startNext, title: "Start break")
        let startFocus = UNNotificationAction(identifier: Self.startNext, title: "Start focus")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.focusDoneTask, actions: [markDone, startBreak], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.focusDoneFree, actions: [startBreak], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.breakDone, actions: [startFocus], intentIdentifiers: []),
        ])
    }

    @MainActor func requestPermission(_ done: @escaping @MainActor (Bool) -> Void) {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in done(granted) }
        }
    }

    func post(title: String, body: String, category: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func clear() {
        center?.removeAllDeliveredNotifications()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        Task { @MainActor in self.onAction?(action) }
        completionHandler()
    }
}
