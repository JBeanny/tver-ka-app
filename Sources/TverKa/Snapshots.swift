import AppKit
import SwiftUI
import TverKaCore

/// Debug aid: `TVERKA_SNAPSHOT_DIR=/some/dir` renders each screen in light and dark to PNGs, then quits.
@MainActor
enum Snapshots {
    static func render(store: TodoStore, sync: SyncController, focus: FocusController, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let editing = store.priorityItems.first?.id ?? store.todayItems.first?.id
        let screens: [(String, AnyView)] = [
            ("today", AnyView(RootView())),
            ("done", AnyView(RootView(screen: .done))),
            ("options", AnyView(RootView(editing: editing))),
            ("projects-dropdown", AnyView(RootView(projectsOpen: true))),
            ("projects-manage", AnyView(RootView(managingProjects: true))),
            ("phone-setup", AnyView(RootView(settingUpPhone: true))),
        ]
        let wasShowingAll = store.showingAll
        func shoot(_ name: String, _ view: AnyView) {
            for scheme in [ColorScheme.light, .dark] {
                let host = NSHostingView(rootView: view.environment(store).environment(sync).environment(focus).environment(\.colorScheme, scheme))
                host.frame = NSRect(x: 0, y: 0, width: 360, height: 640)
                let window = NSWindow(
                    contentRect: NSRect(x: -10_000, y: -10_000, width: 360, height: 640),
                    styleMask: .borderless, backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentView = host
                window.orderFrontRegardless()
                RunLoop.main.run(until: Date().addingTimeInterval(0.8))
                host.layoutSubtreeIfNeeded()
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let file = dir.appendingPathComponent("\(name)-\(scheme == .dark ? "dark" : "light").png")
                try? rep.representation(using: .png, properties: [:])?.write(to: file)
                window.orderOut(nil)
            }
        }
        for (name, view) in screens + [("today-all", AnyView(RootView())), ("done-all", AnyView(RootView(screen: .done)))] {
            if name.hasSuffix("-all") { store.showAll() }
            shoot(name, view)
        }
        if !wasShowingAll { store.selectProject(store.activeProjectID) }

        // Focus mode states (scratch runs only use isolated settings, so this never touches the real app).
        if let task = store.priorityItems.first ?? store.todayItems.first {
            focus.setEnabled(true)
            store.recordPomodoro(todoID: task.id, minutes: 25)
            store.recordPomodoro(todoID: task.id, minutes: 25)
            let now = Date()
            var running = PomodoroTimer()
            running.start(task: task.id, settings: focus.settings, now: now.addingTimeInterval(-378))
            focus.debugSet(timer: running, now: now)
            shoot("focus-running", AnyView(RootView()))
            var onBreak = PomodoroTimer()
            onBreak.start(task: task.id, settings: focus.settings, now: now.addingTimeInterval(-25 * 60 - 48))
            _ = onBreak.tick(now: now.addingTimeInterval(-48), settings: focus.settings)
            focus.debugSet(timer: onBreak, askDone: task.id, now: now)
            shoot("focus-askdone", AnyView(RootView()))
            focus.debugSet(timer: PomodoroTimer(), now: now)
            shoot("focus-settings", AnyView(RootView(focusSettingsOpen: true)))
            shoot("focus-idle", AnyView(RootView()))
        }
        renderMenuBarIcons(to: dir)
        exit(0)
    }

    /// Both icon states on light and dark menu-bar strips, at 6× so they're easy to inspect.
    private static func renderMenuBarIcons(to dir: URL) {
        for (name, appearanceName, bar) in [
            ("light", NSAppearance.Name.aqua, NSColor(white: 0.93, alpha: 1)),
            ("dark", .darkAqua, NSColor(white: 0.16, alpha: 1)),
        ] {
            let scale: CGFloat = 6
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(200 * scale), pixelsHigh: Int(24 * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = NSSize(width: 200, height: 24)
            NSAppearance(named: appearanceName)!.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                bar.setFill()
                NSRect(x: 0, y: 0, width: 200, height: 24).fill()
                MenuBarIcon.image(hot: false).draw(in: NSRect(x: 8, y: 3, width: 21, height: 18))
                MenuBarIcon.image(hot: true).draw(in: NSRect(x: 48, y: 3, width: 21, height: 18))
                MenuBarIcon.focusImage(onBreak: false, paused: false).draw(in: NSRect(x: 88, y: 3, width: 21, height: 18))
                MenuBarIcon.focusImage(onBreak: true, paused: false).draw(in: NSRect(x: 128, y: 3, width: 21, height: 18))
                MenuBarIcon.focusImage(onBreak: false, paused: true).draw(in: NSRect(x: 168, y: 3, width: 21, height: 18))
                NSGraphicsContext.restoreGraphicsState()
            }
            try? rep.representation(using: .png, properties: [:])?
                .write(to: dir.appendingPathComponent("menubar-\(name).png"))
        }
    }
}
