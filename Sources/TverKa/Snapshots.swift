import AppKit
import SwiftUI
import TverKaCore

/// Debug aid: `TVERKA_SNAPSHOT_DIR=/some/dir` renders each screen in light and dark to PNGs, then quits.
@MainActor
enum Snapshots {
    static func render(store: TodoStore, sync: SyncController, to dir: URL) {
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
        for (name, view) in screens + [("today-all", AnyView(RootView())), ("done-all", AnyView(RootView(screen: .done)))] {
            if name.hasSuffix("-all") { store.showAll() }
            for scheme in [ColorScheme.light, .dark] {
                let host = NSHostingView(rootView: view.environment(store).environment(sync).environment(\.colorScheme, scheme))
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
        if !wasShowingAll { store.selectProject(store.activeProjectID) }
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
                bitmapDataPlanes: nil, pixelsWide: Int(80 * scale), pixelsHigh: Int(24 * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = NSSize(width: 80, height: 24)
            NSAppearance(named: appearanceName)!.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                bar.setFill()
                NSRect(x: 0, y: 0, width: 80, height: 24).fill()
                MenuBarIcon.image(hot: false).draw(in: NSRect(x: 8, y: 3, width: 21, height: 18))
                MenuBarIcon.image(hot: true).draw(in: NSRect(x: 48, y: 3, width: 21, height: 18))
                NSGraphicsContext.restoreGraphicsState()
            }
            try? rep.representation(using: .png, properties: [:])?
                .write(to: dir.appendingPathComponent("menubar-\(name).png"))
        }
    }
}
