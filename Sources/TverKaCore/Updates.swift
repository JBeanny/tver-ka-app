import CryptoKit
import Foundation

/// `major.minor.patch`, parsed leniently from tags like "v1.2" or "2.0.0-beta.1" (suffix ignored).
public struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init?(_ text: String) {
        var core = text.trimmingCharacters(in: .whitespaces)
        if core.hasPrefix("v") || core.hasPrefix("V") { core.removeFirst() }
        core = String(core.prefix { $0 != "-" && $0 != "+" })
        let parts = core.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, parts.allSatisfy({ $0 != nil }) else { return nil }
        let n = parts.map { $0! } + Array(repeating: 0, count: 3 - parts.count)
        (major, minor, patch) = (n[0], n[1], n[2])
    }

    public static func < (a: Self, b: Self) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}

/// The parts of a GitHub release we care about.
public struct Release: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public var name: String
        public var downloadURL: URL
        public var size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case downloadURL = "browser_download_url"
        }
    }

    public var tagName: String
    public var name: String?
    public var body: String?
    public var htmlURL: URL?
    public var prerelease: Bool
    public var draft: Bool
    public var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, assets, prerelease, draft
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try c.decode(String.self, forKey: .tagName)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        htmlURL = try c.decodeIfPresent(URL.self, forKey: .htmlURL)
        prerelease = try c.decodeIfPresent(Bool.self, forKey: .prerelease) ?? false
        draft = try c.decodeIfPresent(Bool.self, forKey: .draft) ?? false
        assets = try c.decodeIfPresent([Asset].self, forKey: .assets) ?? []
    }

    public var version: SemanticVersion? { SemanticVersion(tagName) }
    public var zipAsset: Asset? { assets.first { $0.name.lowercased().hasSuffix(".zip") } }
    public var checksumAsset: Asset? {
        guard let zip = zipAsset else { return nil }
        return assets.first { $0.name == zip.name + ".sha256" }
    }
    public var notes: String { body ?? "" }

    /// A published, non-prerelease release with a downloadable zip and a higher version.
    public func isNewer(than current: String) -> Bool {
        guard !draft, !prerelease, zipAsset != nil, let mine = SemanticVersion(current), let theirs = version else {
            return false
        }
        return theirs > mine
    }

    /// Reads a release from a GitHub API URL (or a local file, for testing).
    public static func fetch(from url: URL) async throws -> Release {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateError.server(http.statusCode)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }
}

public enum UpdateError: Error, Equatable, LocalizedError {
    case server(Int)
    case checksumMismatch
    case unzipFailed
    case noApp
    case wrongApp
    case notNewer
    case notWritable(String)
    case translocated

    public var errorDescription: String? {
        switch self {
        case .server(let code): "GitHub answered with an error (\(code)). Try again in a bit."
        case .checksumMismatch: "The download didn't match its checksum, so it wasn't installed."
        case .unzipFailed: "Couldn't unpack the download."
        case .noApp: "The download didn't contain the app."
        case .wrongApp: "The download wasn't Tver Ka, so it wasn't installed."
        case .notNewer: "The download isn't newer than this version."
        case .notWritable(let folder): "Tver Ka can't replace itself in \(folder). Move it into Applications first."
        case .translocated: "macOS is running Tver Ka from a temporary spot. Move it into Applications, open it from there, then update."
        }
    }
}

/// Checks and unpacks a downloaded release zip before anything gets replaced.
public enum UpdatePackage {
    public struct Ready: Sendable {
        public var appURL: URL
        public var version: SemanticVersion
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// `shasum` output: "<64 hex>  <file>".
    public static func parseChecksum(_ text: String) -> String? {
        guard let token = text.split(whereSeparator: \.isWhitespace).first?.lowercased(),
              token.count == 64, token.allSatisfy(\.isHexDigit)
        else { return nil }
        return token
    }

    /// Verifies the checksum, unzips into `workDir`, and checks it's this app at a newer version.
    public static func prepare(
        zip: URL, expectedSHA256: String?, bundleID: String, currentVersion: String, workDir: URL
    ) throws -> Ready {
        if let expected = expectedSHA256, try sha256(of: zip) != expected.lowercased() {
            throw UpdateError.checksumMismatch
        }
        let out = workDir.appendingPathComponent("unpacked-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, out.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw UpdateError.unzipFailed }

        guard let name = try FileManager.default.contentsOfDirectory(atPath: out.path).first(where: { $0.hasSuffix(".app") })
        else { throw UpdateError.noApp }
        let app = out.appendingPathComponent(name)
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else {
            throw UpdateError.noApp
        }
        guard info["CFBundleIdentifier"] as? String == bundleID else { throw UpdateError.wrongApp }
        guard let version = (info["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init),
              let current = SemanticVersion(currentVersion), version > current
        else { throw UpdateError.notNewer }
        return Ready(appURL: app, version: version)
    }
}
