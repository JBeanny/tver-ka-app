import AppKit
import SwiftUI
import TverKaCore

@main
struct TverKaApp: App {
    @State private var store: TodoStore
    @State private var sync: SyncController
    @State private var focus: FocusController
    @State private var updates: UpdateController
    @State private var watcher: DayWatcher

    init() {
        let paths = SyncPaths(localData: AppEnvironment.dataFile, iCloudRoot: AppEnvironment.iCloudRoot)
        let store = TodoStore(fileURL: SyncController.launchDataFile(paths), now: AppEnvironment.now)
        let sync = SyncController(store: store, paths: paths)
        let focus = FocusController(store: store)
        let updates = UpdateController()
        _store = State(initialValue: store)
        _sync = State(initialValue: sync)
        _focus = State(initialValue: focus)
        _updates = State(initialValue: updates)
        _watcher = State(initialValue: DayWatcher(store: store, sync: sync, focus: focus, updates: updates))
        DispatchQueue.main.async { LaunchHygiene.run() }
        if AppEnvironment.snapshotDir == nil {
            DispatchQueue.main.async { sync.tick() }
        }
        DispatchQueue.main.async { Appearance.saved.apply() }
        if let dir = AppEnvironment.snapshotDir {
            DispatchQueue.main.async { Snapshots.render(store: store, sync: sync, focus: focus, updates: updates, to: dir) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environment(store)
                .environment(sync)
                .environment(focus)
                .environment(updates)
        } label: {
            HStack(spacing: 3) {
                if focus.isActive {
                    Image(nsImage: MenuBarIcon.focusImage(onBreak: focus.timer.phase.isBreak, paused: focus.timer.isPaused))
                    Text(focus.clock).monospacedDigit()
                } else {
                    Image(nsImage: MenuBarIcon.image(hot: store.anyOpenPriority))
                    if store.totalOpenCount > 0 {
                        Text("\(store.totalOpenCount)")
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Runtime knobs, mostly for testing rollover by hand:
/// `TVERKA_DAY_OFFSET=1` pretends it's tomorrow, `TVERKA_DATA_FILE` points at a scratch file,
/// `TVERKA_ICLOUD_ROOT` stands in for `~/Library/Mobile Documents` so testing never touches real iCloud.
enum AppEnvironment {
    private static let env = ProcessInfo.processInfo.environment
    static let dayOffset = Double(env["TVERKA_DAY_OFFSET"] ?? "") ?? 0
    /// `TVERKA_FOCUS_SCALE=60` runs Focus mode 60× faster (a minute per second) for testing.
    static let focusSecondsPerMinute = 60 / max(1, Double(env["TVERKA_FOCUS_SCALE"] ?? "") ?? 1)
    static let snapshotDir = env["TVERKA_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    static let dataFile = env["TVERKA_DATA_FILE"].map { URL(fileURLWithPath: $0) } ?? TodoStore.defaultFileURL
    /// Any debug data override isolates the run from the real iCloud Drive and the real settings,
    /// so a scratch run can never read or write the user's synced to-dos.
    static let usesFakeICloud = env["TVERKA_ICLOUD_ROOT"] != nil || env["TVERKA_DATA_FILE"] != nil
    static let iCloudRoot: URL = {
        if let root = env["TVERKA_ICLOUD_ROOT"] { return URL(fileURLWithPath: root) }
        if env["TVERKA_DATA_FILE"] != nil {
            // No iCloud at all: a path that never exists, so sync reads as unavailable.
            return FileManager.default.temporaryDirectory.appendingPathComponent("tverka-no-icloud-\(UUID().uuidString)")
        }
        return SyncPaths.defaultICloudRoot
    }()

    @Sendable static func now() -> Date {
        Date().addingTimeInterval(dayOffset * 86_400)
    }
}

/// Re-runs rollover when the calendar day changes and after wake, and every few seconds
/// checks iCloud for changes and iPhone inbox items (which also backstops rollover).
@MainActor
final class DayWatcher {
    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?

    init(store: TodoStore, sync: SyncController, focus: FocusController, updates: UpdateController) {
        let roll: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in
                sync.tick()
                store.rollOver()
                focus.tick()
            }
        }
        tokens.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main, using: roll))
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: roll))
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                sync.tick()
                store.rollOver()
                updates.autoCheckIfDue()
            }
        }
    }
}
