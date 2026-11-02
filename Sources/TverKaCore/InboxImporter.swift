import Foundation

/// One to-do dropped into the inbox, e.g. by the iPhone Shortcut.
public struct InboxItem: Equatable, Sendable {
    public var title: String
    public var projectName: String?
    public var priority: Bool
}

/// Inbox text format: the first non-empty line is the title,
/// an optional leading `#project` picks the project, a trailing `!` marks it priority.
public enum InboxParser {
    public static func parse(_ text: String) -> InboxItem? {
        guard var line = text.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty })
        else { return nil }

        var project: String?
        if line.hasPrefix("#") {
            let tag = line.prefix { !$0.isWhitespace }
            project = String(tag.dropFirst())
            line = String(line.dropFirst(tag.count)).trimmingCharacters(in: .whitespaces)
        }

        var priority = false
        while line.hasSuffix("!") {
            priority = true
            line = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        guard !line.isEmpty else { return nil }
        return InboxItem(title: line, projectName: project?.isEmpty == true ? nil : project, priority: priority)
    }
}

/// Imports `*.txt` files from a folder (the iCloud Drive inbox) into the store, then deletes them.
@MainActor
public struct InboxImporter {
    public let folder: URL
    /// Asks iCloud to download a file that's only a placeholder on this Mac so far.
    public var requestDownload: (URL) -> Void

    public init(folder: URL, requestDownload: @escaping (URL) -> Void = InboxImporter.downloadFromICloud) {
        self.folder = folder
        self.requestDownload = requestDownload
    }

    /// Returns how many to-dos were added.
    @discardableResult
    public func run(into store: TodoStore) -> Int {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return 0 }

        var added = 0
        for name in names.sorted() {
            // Not downloaded yet: iCloud shows it as ".name.txt.icloud".
            if name.hasPrefix("."), name.hasSuffix(".txt.icloud") {
                requestDownload(folder.appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count))))
                continue
            }
            guard name.hasSuffix(".txt"), !name.hasPrefix(".") else { continue }
            let file = folder.appendingPathComponent(name)
            guard let text = CoordinatedFile.read(file).flatMap({ String(data: $0, encoding: .utf8) }) else { continue }
            if let item = InboxParser.parse(text) {
                store.add(item.title, projectNamed: item.projectName, priority: item.priority)
                added += 1
            }
            CoordinatedFile.delete(file)
        }
        return added
    }

    public static let downloadFromICloud: (URL) -> Void = { url in
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            let brctl = Process()
            brctl.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
            brctl.arguments = ["download", url.path]
            try? brctl.run()
        }
    }
}

/// File access through NSFileCoordinator, so reads and writes play nicely with iCloud Drive syncing.
enum CoordinatedFile {
    static func read(_ url: URL) -> Data? {
        var data: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { data = try? Data(contentsOf: $0) }
        return data
    }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordError ?? writeError { throw error }
    }

    static func delete(_ url: URL) {
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error) {
            try? FileManager.default.removeItem(at: $0)
        }
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
