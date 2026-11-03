import Foundation
import Testing
@testable import TverKaCore

@Suite struct SemanticVersionTests {
    @Test func parsesTagsAndComparesNumerically() {
        #expect(SemanticVersion("v1.10.0")! > SemanticVersion("1.9.9")!)
        #expect(SemanticVersion("1.2")! == SemanticVersion("1.2.0")!)
        #expect(SemanticVersion("2.0.0-beta.1")! == SemanticVersion("2.0.0")!)
        #expect(SemanticVersion("nope") == nil)
    }
}

let sampleRelease = """
{
  "tag_name": "v1.3.0",
  "name": "Tver Ka 1.3.0",
  "body": "**New**\\n- things",
  "html_url": "https://github.com/JBeanny/tver-ka-app/releases/tag/v1.3.0",
  "draft": false,
  "prerelease": false,
  "assets": [
    {"name": "Tver-Ka-1.3.0.zip.sha256", "browser_download_url": "https://example.com/a.sha256", "size": 90},
    {"name": "Tver-Ka-1.3.0.zip", "browser_download_url": "https://example.com/a.zip", "size": 1300000}
  ]
}
"""

@Suite struct ReleaseTests {
    @Test func decodesGitHubReleaseJSON() throws {
        let r = try JSONDecoder().decode(Release.self, from: Data(sampleRelease.utf8))
        #expect(r.version == SemanticVersion("1.3.0"))
        #expect(r.zipAsset?.name == "Tver-Ka-1.3.0.zip")
        #expect(r.checksumAsset?.name == "Tver-Ka-1.3.0.zip.sha256")
        #expect(r.notes.contains("things"))
    }

    @Test func newerOnlyWhenTheReleaseIsAheadAndHasAZip() throws {
        let r = try JSONDecoder().decode(Release.self, from: Data(sampleRelease.utf8))
        #expect(r.isNewer(than: "1.2.0"))
        #expect(!r.isNewer(than: "1.3.0"))
        #expect(!r.isNewer(than: "2.0"))

        var noZip = r
        noZip.assets = []
        #expect(!noZip.isNewer(than: "1.2.0"))
        var pre = r
        pre.prerelease = true
        #expect(!pre.isNewer(than: "1.2.0"))
    }

    @Test func fetchReadsAFeedURL() async throws {
        let file = tempDir().appendingPathComponent("latest.json")
        try Data(sampleRelease.utf8).write(to: file)
        let r = try await Release.fetch(from: file)
        #expect(r.tagName == "v1.3.0")
    }

    @Test func checksumFileParsing() {
        #expect(UpdatePackage.parseChecksum("ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef0123456789  build/x.zip\n")
            == "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789")
        #expect(UpdatePackage.parseChecksum("garbage") == nil)
    }
}

@Suite struct UpdatePackageTests {
    /// Builds a zip that looks like a release: "<name>.app" with an Info.plist.
    func makeZip(bundleID: String = "dev.tverka.app", version: String = "1.3.0", appName: String = "Tver Ka") throws -> URL {
        let src = tempDir()
        let contents = src.appendingPathComponent("\(appName).app/Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundleShortVersionString": version]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("#!/bin/sh\n".utf8).write(to: contents.appendingPathComponent("MacOS/TverKa"))
        let zip = tempDir().appendingPathComponent("release.zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--keepParent", src.appendingPathComponent("\(appName).app").path, zip.path]
        try ditto.run()
        ditto.waitUntilExit()
        return zip
    }

    @Test func preparesAValidNewerApp() throws {
        let zip = try makeZip()
        let sum = try UpdatePackage.sha256(of: zip)
        let ready = try UpdatePackage.prepare(
            zip: zip, expectedSHA256: sum, bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        #expect(ready.appURL.lastPathComponent == "Tver Ka.app")
        #expect(ready.version == SemanticVersion("1.3.0"))
        #expect(FileManager.default.fileExists(atPath: ready.appURL.appendingPathComponent("Contents/Info.plist").path))
    }

    @Test func rejectsChecksumMismatch() throws {
        let zip = try makeZip()
        #expect(throws: UpdateError.checksumMismatch) {
            try UpdatePackage.prepare(zip: zip, expectedSHA256: String(repeating: "0", count: 64),
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsADifferentApp() throws {
        let zip = try makeZip(bundleID: "com.someone.else")
        #expect(throws: UpdateError.wrongApp) {
            try UpdatePackage.prepare(zip: zip, expectedSHA256: nil, bundleID: "dev.tverka.app",
                                      currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsAnOlderOrSameVersion() throws {
        let zip = try makeZip(version: "1.2.0")
        #expect(throws: UpdateError.notNewer) {
            try UpdatePackage.prepare(zip: zip, expectedSHA256: nil, bundleID: "dev.tverka.app",
                                      currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func acceptsTheOldAppNameToo() throws {
        let zip = try makeZip(appName: "tver-ka")
        let ready = try UpdatePackage.prepare(zip: zip, expectedSHA256: nil, bundleID: "dev.tverka.app",
                                              currentVersion: "1.2.0", workDir: tempDir())
        #expect(ready.appURL.lastPathComponent == "tver-ka.app")
    }
}
