import AppKit
import Observation
import TverKaCore

/// Checks GitHub Releases for a newer Tver Ka and replaces this copy in place, so there's never a second one.
@MainActor
@Observable
final class UpdateController {
    enum State: Equatable {
        case idle, checking, upToDate, available, downloading, installing
        case failed(String)
    }

    private static let autoCheckKey = "autoUpdateCheck"
    private static let lastCheckKey = "lastUpdateCheck"
    static let feedURL = URL(string: ProcessInfo.processInfo.environment["TVERKA_UPDATE_FEED"]
        ?? "https://api.github.com/repos/JBeanny/tver-ka-app/releases/latest")!

    private(set) var state: State = .idle
    private(set) var release: Release?
    private(set) var autoCheck: Bool

    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let bundleID = Bundle.main.bundleIdentifier ?? "dev.tverka.app"

    init() {
        let defaults = SyncController.defaults
        autoCheck = defaults.object(forKey: Self.autoCheckKey) as? Bool ?? true
    }

    var isUpdateAvailable: Bool { release != nil }
    var isBusy: Bool { [.checking, .downloading, .installing].contains(state) }

    func setAutoCheck(_ on: Bool) {
        autoCheck = on
        SyncController.defaults.set(on, forKey: Self.autoCheckKey)
    }

    /// Cheap to call often: checks at most once a day, and only if automatic checks are on.
    func autoCheckIfDue() {
        guard autoCheck, !isBusy, release == nil, AppEnvironment.snapshotDir == nil else { return }
        let last = SyncController.defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 60 * 60 else { return }
        Task { await check() }
    }

    func check() async {
        guard !isBusy else { return }
        state = .checking
        do {
            let latest = try await Release.fetch(from: Self.feedURL)
            SyncController.defaults.set(Date(), forKey: Self.lastCheckKey)
            if latest.isNewer(than: currentVersion) {
                release = latest
                state = .available
                // Test knob: install without a click (used to exercise the full swap end to end).
                if ProcessInfo.processInfo.environment["TVERKA_UPDATE_AUTOINSTALL"] == "1" { await install() }
            } else {
                release = nil
                state = .upToDate
            }
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription
                ?? "Couldn't reach GitHub. Check your connection and try again.")
        }
    }

    /// Downloads, verifies, then quits and swaps the app in place via a tiny helper script, and relaunches.
    func install() async {
        guard let release, let zipAsset = release.zipAsset, !isBusy else { return }
        let bundle = Bundle.main.bundleURL
        do {
            if bundle.path.contains("/AppTranslocation/") { throw UpdateError.translocated }
            let folder = bundle.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: folder.path) else {
                throw UpdateError.notWritable(folder.path)
            }

            state = .downloading
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("TverKaUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = work.appendingPathComponent(zipAsset.name)
            let (downloaded, _) = try await URLSession.shared.download(from: zipAsset.downloadURL)
            try FileManager.default.moveItem(at: downloaded, to: zip)
            var checksum: String?
            if let sumAsset = release.checksumAsset {
                let (data, _) = try await URLSession.shared.data(from: sumAsset.downloadURL)
                checksum = UpdatePackage.parseChecksum(String(decoding: data, as: UTF8.self))
            }

            state = .installing
            let ready = try UpdatePackage.prepare(
                zip: zip, expectedSHA256: checksum, bundleID: bundleID, currentVersion: currentVersion, workDir: work)
            try launchSwap(newApp: ready.appURL, old: bundle, target: folder.appendingPathComponent("Tver Ka.app"), work: work)
            NSApp.terminate(nil)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Waits for this process to quit, copies the new app next to the old one, removes the old one
    /// (whatever it was called), moves the new one into place, and opens it. If copying fails, the old app stays.
    private func launchSwap(newApp: URL, old: URL, target: URL, work: URL) throws {
        let script = work.appendingPathComponent("swap.sh")
        try """
        #!/bin/bash
        pid="$1"; new="$2"; old="$3"; target="$4"
        for _ in $(seq 1 150); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
        staging="$target.updating"
        rm -rf "$staging"
        /usr/bin/ditto "$new" "$staging" || exit 1
        rm -rf "$old"
        [ "$old" != "$target" ] && rm -rf "$target"
        mv "$staging" "$target" || exit 1
        /usr/bin/xattr -dr com.apple.quarantine "$target" 2>/dev/null
        if [ -n "$TVERKA_DATA_FILE" ]; then
          # Test runs relaunch with their scratch settings instead of as the real app.
          nohup "$target/Contents/MacOS/TverKa" >/dev/null 2>&1 &
        else
          /usr/bin/open "$target"
        fi
        """.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "\(ProcessInfo.processInfo.processIdentifier)", newApp.path, old.path, target.path]
        try process.run()
    }

    // MARK: - Snapshot support

    func debugShow(_ release: Release?, state: State) {
        self.release = release
        self.state = state
    }
}

/// Launch housekeeping so there's only ever one Tver Ka: closes other running copies and moves
/// older installed copies (including the pre-rename "tver-ka.app") to the Trash.
@MainActor
enum LaunchHygiene {
    static func run() {
        // Never during test/debug runs, which must not touch the real app.
        guard !AppEnvironment.usesFakeICloud, AppEnvironment.snapshotDir == nil,
              let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = Bundle.main.bundleURL.standardizedFileURL

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.terminate()
        }

        // Only tidy up when we ourselves live in an Applications folder (not a dev build).
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appFolders = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
        guard appFolders.contains(where: { me.deletingLastPathComponent().standardizedFileURL == $0.standardizedFileURL })
        else { return }
        let myVersion = SemanticVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")

        var stale: [URL] = []
        for folder in appFolders {
            for name in ["tver-ka.app", "Tver Ka.app"] {
                let candidate = folder.appendingPathComponent(name).standardizedFileURL
                guard candidate != me, let other = Bundle(url: candidate), other.bundleIdentifier == bundleID else { continue }
                let theirs = SemanticVersion(other.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                if let mine = myVersion, let theirs, theirs > mine { continue }
                stale.append(candidate)
            }
        }
        if !stale.isEmpty {
            NSWorkspace.shared.recycle(stale) { _, error in
                if let error { NSLog("Tver Ka: couldn't move an old copy to the Trash: \(error)") }
            }
        }
    }
}
