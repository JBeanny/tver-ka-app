import Foundation

/// Where Tver Ka keeps things when syncing through iCloud Drive.
public struct SyncPaths: Sendable {
    /// The non-synced data file in Application Support.
    public var localData: URL
    /// `~/Library/Mobile Documents`, overridable for tests.
    public var iCloudRoot: URL

    public init(localData: URL, iCloudRoot: URL) {
        self.localData = localData
        self.iCloudRoot = iCloudRoot
    }

    nonisolated public static var defaultICloudRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents")
    }

    public var iCloudDrive: URL { iCloudRoot.appendingPathComponent("com~apple~CloudDocs") }
    /// iCloud Drive › Shortcuts, which Shortcuts can read and write by plain subpath.
    public var shortcutsFolder: URL { iCloudRoot.appendingPathComponent("iCloud~is~workflow~my~workflows/Documents") }

    public var cloudData: URL { iCloudDrive.appendingPathComponent("tver-ka/todos.json") }
    public var inbox: URL { shortcutsFolder.appendingPathComponent("tver-ka/inbox") }
    public var digest: URL { shortcutsFolder.appendingPathComponent("tver-ka/Today.md") }
    public var localBackup: URL { localData.deletingLastPathComponent().appendingPathComponent("todos.local-backup.json") }

    public var isICloudAvailable: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: iCloudDrive.path, isDirectory: &isDir) && isDir.boolValue
    }
}

public enum SyncMigration {
    /// Moves to iCloud. Existing iCloud data wins; local data is kept as a backup in that case.
    /// Returns the data file to use.
    public static func enable(_ paths: SyncPaths) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.cloudData.deletingLastPathComponent(), withIntermediateDirectories: true)
        let hasLocal = fm.fileExists(atPath: paths.localData.path)
        if fm.fileExists(atPath: paths.cloudData.path) {
            if hasLocal { try replace(paths.localBackup, with: paths.localData) }
        } else if hasLocal {
            try replace(paths.cloudData, with: paths.localData)
        }
        return paths.cloudData
    }

    /// Moves back to the local file, taking iCloud's latest data along. Returns the data file to use.
    public static func disable(_ paths: SyncPaths) throws -> URL {
        if FileManager.default.fileExists(atPath: paths.cloudData.path) {
            try FileManager.default.createDirectory(
                at: paths.localData.deletingLastPathComponent(), withIntermediateDirectories: true)
            try replace(paths.localData, with: paths.cloudData)
        }
        return paths.localData
    }

    private static func replace(_ destination: URL, with source: URL) throws {
        guard let data = CoordinatedFile.read(source) else { return }
        try CoordinatedFile.write(data, to: destination)
    }
}
