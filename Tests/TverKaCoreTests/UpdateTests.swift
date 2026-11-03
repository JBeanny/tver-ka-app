import CryptoKit
import Foundation
import Testing
@testable import TverKaCore

let testKey = Curve25519.Signing.PrivateKey()
func sign(_ zip: URL, with key: Curve25519.Signing.PrivateKey = testKey) throws -> Data {
    try key.signature(for: Data(contentsOf: zip))
}

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
    {"name": "Tver-Ka-1.3.0.zip.sig", "browser_download_url": "https://github.com/JBeanny/tver-ka-app/releases/download/v1.3.0/Tver-Ka-1.3.0.zip.sig", "size": 90},
    {"name": "Tver-Ka-1.3.0.zip", "browser_download_url": "https://github.com/JBeanny/tver-ka-app/releases/download/v1.3.0/Tver-Ka-1.3.0.zip", "size": 1300000}
  ]
}
"""

@Suite struct ReleaseTests {
    @Test func decodesGitHubReleaseJSON() throws {
        let r = try JSONDecoder().decode(Release.self, from: Data(sampleRelease.utf8))
        #expect(r.version == SemanticVersion("1.3.0"))
        #expect(r.zipAsset?.name == "Tver-Ka-1.3.0.zip")
        #expect(r.signatureAsset?.name == "Tver-Ka-1.3.0.zip.sig")
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

    @Test func onlyGitHubHTTPSDownloadsAreTrusted() {
        #expect(Release.isTrustedDownload(URL(string: "https://github.com/JBeanny/tver-ka-app/releases/download/v1/x.zip")!, allowLocal: false))
        #expect(Release.isTrustedDownload(URL(string: "https://objects.githubusercontent.com/x")!, allowLocal: false))
        #expect(!Release.isTrustedDownload(URL(string: "http://github.com/x.zip")!, allowLocal: false))
        #expect(!Release.isTrustedDownload(URL(string: "https://evil.example/x.zip")!, allowLocal: false))
        #expect(!Release.isTrustedDownload(URL(string: "https://github.com.evil.example/x.zip")!, allowLocal: false))
        #expect(!Release.isTrustedDownload(URL(fileURLWithPath: "/tmp/x.zip"), allowLocal: false))
        #expect(Release.isTrustedDownload(URL(fileURLWithPath: "/tmp/x.zip"), allowLocal: true))
    }

    @Test func signatureFileParsing() {
        let sig = Data(repeating: 7, count: 64)
        #expect(UpdatePackage.parseSignature(sig.base64EncodedString() + "\n") == sig)
        #expect(UpdatePackage.parseSignature("not base64!") == nil)
        #expect(UpdatePackage.parseSignature(Data(count: 10).base64EncodedString()) == nil)
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
        let ready = try UpdatePackage.prepare(
            zip: zip, signature: try sign(zip), publicKey: testKey.publicKey.rawRepresentation,
            bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        #expect(ready.appURL.lastPathComponent == "Tver Ka.app")
        #expect(ready.version == SemanticVersion("1.3.0"))
        #expect(FileManager.default.fileExists(atPath: ready.appURL.appendingPathComponent("Contents/Info.plist").path))
    }

    @Test func rejectsAMissingSignature() throws {
        let zip = try makeZip()
        #expect(throws: UpdateError.badSignature) {
            try UpdatePackage.prepare(zip: zip, signature: nil, publicKey: testKey.publicKey.rawRepresentation,
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsASignatureFromAnotherKey() throws {
        let zip = try makeZip()
        let impostor = Curve25519.Signing.PrivateKey()
        #expect(throws: UpdateError.badSignature) {
            try UpdatePackage.prepare(zip: zip, signature: try sign(zip, with: impostor),
                                      publicKey: testKey.publicKey.rawRepresentation,
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsATamperedZip() throws {
        let zip = try makeZip()
        let signature = try sign(zip)
        let handle = try FileHandle(forWritingTo: zip)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x42]))
        try handle.close()
        #expect(throws: UpdateError.badSignature) {
            try UpdatePackage.prepare(zip: zip, signature: signature, publicKey: testKey.publicKey.rawRepresentation,
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsADifferentApp() throws {
        let zip = try makeZip(bundleID: "com.someone.else")
        #expect(throws: UpdateError.wrongApp) {
            try UpdatePackage.prepare(zip: zip, signature: try sign(zip), publicKey: testKey.publicKey.rawRepresentation,
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func rejectsAnOlderOrSameVersion() throws {
        let zip = try makeZip(version: "1.2.0")
        #expect(throws: UpdateError.notNewer) {
            try UpdatePackage.prepare(zip: zip, signature: try sign(zip), publicKey: testKey.publicKey.rawRepresentation,
                                      bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        }
    }

    @Test func acceptsTheOldAppNameToo() throws {
        let zip = try makeZip(appName: "tver-ka")
        let ready = try UpdatePackage.prepare(
            zip: zip, signature: try sign(zip), publicKey: testKey.publicKey.rawRepresentation,
            bundleID: "dev.tverka.app", currentVersion: "1.2.0", workDir: tempDir())
        #expect(ready.appURL.lastPathComponent == "tver-ka.app")
    }
}
