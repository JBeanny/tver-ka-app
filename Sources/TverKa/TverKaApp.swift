import AppKit
import SwiftUI
import TverKaCore

@main
struct TverKaApp: App {
    @State private var store: TodoStore
    @State private var watcher: DayWatcher

    init() {
        let store = TodoStore(fileURL: AppEnvironment.dataFile, now: AppEnvironment.now)
        _store = State(initialValue: store)
        _watcher = State(initialValue: DayWatcher(store: store))
        DispatchQueue.main.async { Appearance.saved.apply() }
        if let dir = AppEnvironment.snapshotDir {
            DispatchQueue.main.async { Snapshots.render(store: store, to: dir) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environment(store)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: MenuBarIcon.image(hot: store.anyOpenPriority))
                if store.totalOpenCount > 0 {
                    Text("\(store.totalOpenCount)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Runtime knobs, mostly for testing rollover by hand:
/// `TVERKA_DAY_OFFSET=1` pretends it's tomorrow, `TVERKA_DATA_FILE` points at a scratch file.
enum AppEnvironment {
    private static let env = ProcessInfo.processInfo.environment
    static let dayOffset = Double(env["TVERKA_DAY_OFFSET"] ?? "") ?? 0
    static let snapshotDir = env["TVERKA_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    static let dataFile = env["TVERKA_DATA_FILE"].map { URL(fileURLWithPath: $0) } ?? TodoStore.defaultFileURL

    @Sendable static func now() -> Date {
        Date().addingTimeInterval(dayOffset * 86_400)
    }
}

/// Re-runs rollover when the calendar day changes, after wake, and once a minute as a backstop.
@MainActor
final class DayWatcher {
    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?

    init(store: TodoStore) {
        let roll: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in store.rollOver() }
        }
        tokens.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main, using: roll))
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: roll))
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in store.rollOver() }
        }
    }
}
