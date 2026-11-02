import Foundation
import Observation
import TverKaCore

/// Owns the "Sync with iCloud" setting: where the data lives, the iPhone inbox, and the Today.md digest.
@MainActor
@Observable
final class SyncController {
    static let enabledKey = "iCloudSync"

    let paths: SyncPaths
    private let store: TodoStore
    private(set) var isEnabled: Bool
    private(set) var lastImport: Date?
    private(set) var lastError: String?

    var isAvailable: Bool { paths.isICloudAvailable }

    /// A fake iCloud root (testing) gets its own settings, so it can never flip the real app's sync setting.
    static var defaults: UserDefaults {
        AppEnvironment.usesFakeICloud ? UserDefaults(suiteName: "dev.tverka.app.test")! : .standard
    }

    /// The data file to open on launch, before a store exists.
    static func launchDataFile(_ paths: SyncPaths) -> URL {
        guard defaults.bool(forKey: enabledKey), paths.isICloudAvailable else { return paths.localData }
        let fm = FileManager.default
        let cloud = paths.cloudData
        if !fm.fileExists(atPath: cloud.path) {
            // On a fresh Mac the file may exist only as an iCloud placeholder: wait for it rather than
            // creating an empty file that would clash with the real one.
            let placeholder = cloud.deletingLastPathComponent().appendingPathComponent(".todos.json.icloud")
            if fm.fileExists(atPath: placeholder.path) {
                InboxImporter.downloadFromICloud(cloud)
                let deadline = Date().addingTimeInterval(15)
                while !fm.fileExists(atPath: cloud.path), Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.25)
                }
            }
            if !fm.fileExists(atPath: cloud.path) { _ = try? SyncMigration.enable(paths) }
        }
        return cloud
    }

    init(store: TodoStore, paths: SyncPaths) {
        self.store = store
        self.paths = paths
        self.isEnabled = Self.defaults.bool(forKey: Self.enabledKey) && paths.isICloudAvailable
        if isEnabled { store.digestURL = paths.digest }
    }

    func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        do {
            if on {
                guard isAvailable else {
                    lastError = "iCloud Drive isn't turned on for this Mac."
                    return
                }
                store.relocate(to: try SyncMigration.enable(paths))
                store.digestURL = paths.digest
            } else {
                store.digestURL = nil
                store.relocate(to: try SyncMigration.disable(paths))
            }
            isEnabled = on
            lastError = nil
            Self.defaults.set(on, forKey: Self.enabledKey)
            tick()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Pulls in changes from iCloud and imports anything the iPhone dropped in the inbox.
    func tick() {
        guard isEnabled else { return }
        store.reloadIfChangedExternally()
        if InboxImporter(folder: paths.inbox).run(into: store) > 0 {
            lastImport = Date()
        }
    }
}
