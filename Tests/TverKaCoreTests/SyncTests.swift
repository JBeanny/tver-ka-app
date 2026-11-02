import Foundation
import Testing
@testable import TverKaCore

func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tverka-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Suite struct InboxParserTests {
    @Test func plainTitle() {
        #expect(InboxParser.parse("buy oat milk") == InboxItem(title: "buy oat milk", projectName: nil, priority: false))
    }

    @Test func projectTagAndPriority() {
        #expect(InboxParser.parse("#Work ship the deck !") == InboxItem(title: "ship the deck", projectName: "Work", priority: true))
    }

    @Test func usesFirstNonEmptyLineAndTrims() {
        #expect(InboxParser.parse("\n\n   call grandma  \nsecond line") == InboxItem(title: "call grandma", projectName: nil, priority: false))
    }

    @Test func emptyOrTagOnlyIsNil() {
        #expect(InboxParser.parse("   \n ") == nil)
        #expect(InboxParser.parse("#work") == nil)
        #expect(InboxParser.parse("!") == nil)
    }
}

@MainActor
@Suite struct InboxImporterTests {
    func store() -> TodoStore {
        TodoStore(fileURL: tempDir().appendingPathComponent("todos.json"), calendar: utc, now: { day(2026, 11, 2) })
    }

    @Test func importsTextFilesInNameOrderAndDeletesThem() throws {
        let inbox = tempDir()
        try "second".write(to: inbox.appendingPathComponent("20261102-2.txt"), atomically: true, encoding: .utf8)
        try "first".write(to: inbox.appendingPathComponent("20261102-1.txt"), atomically: true, encoding: .utf8)
        let s = store()

        let count = InboxImporter(folder: inbox, requestDownload: { _ in }).run(into: s)

        #expect(count == 2)
        #expect(s.todayItems.map(\.title) == ["first", "second"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: inbox.path).isEmpty)
    }

    @Test func routesToProjectsAndPriority() throws {
        let inbox = tempDir()
        try "#WORK send invoice !".write(to: inbox.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "#nope stray".write(to: inbox.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let s = store()
        let personal = s.projects[0]
        let work = s.addProject("work")
        s.selectProject(personal.id)

        InboxImporter(folder: inbox, requestDownload: { _ in }).run(into: s)

        let invoice = s.todos.first { $0.title == "send invoice" }
        #expect(invoice?.projectID == work.id)
        #expect(invoice?.isPriority == true)
        #expect(s.todos.first { $0.title == "stray" }?.projectID == personal.id)
    }

    @Test func blankFilesAreDeletedWithoutAddingAnything() throws {
        let inbox = tempDir()
        try "   ".write(to: inbox.appendingPathComponent("blank.txt"), atomically: true, encoding: .utf8)
        let s = store()
        #expect(InboxImporter(folder: inbox, requestDownload: { _ in }).run(into: s) == 0)
        #expect(s.todos.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: inbox.path).isEmpty)
    }

    @Test func placeholdersAreDownloadedNotImported() throws {
        let inbox = tempDir()
        try Data().write(to: inbox.appendingPathComponent(".later.txt.icloud"))
        var requested: [String] = []
        let s = store()

        let count = InboxImporter(folder: inbox, requestDownload: { requested.append($0.lastPathComponent) }).run(into: s)

        #expect(count == 0)
        #expect(requested == ["later.txt"])
        #expect(FileManager.default.fileExists(atPath: inbox.appendingPathComponent(".later.txt.icloud").path))
    }

    @Test func missingInboxIsCreated() {
        let inbox = tempDir().appendingPathComponent("tver-ka/inbox")
        #expect(InboxImporter(folder: inbox, requestDownload: { _ in }).run(into: store()) == 0)
        #expect(FileManager.default.fileExists(atPath: inbox.path))
    }
}

@Suite struct SyncMigrationTests {
    func paths() -> SyncPaths {
        let root = tempDir()
        try! FileManager.default.createDirectory(
            at: root.appendingPathComponent("com~apple~CloudDocs"), withIntermediateDirectories: true)
        return SyncPaths(localData: tempDir().appendingPathComponent("todos.json"), iCloudRoot: root)
    }

    @Test func availabilityFollowsICloudDriveFolder() {
        #expect(paths().isICloudAvailable)
        #expect(!SyncPaths(localData: tempDir(), iCloudRoot: tempDir()).isICloudAvailable)
    }

    @Test func enableCopiesLocalDataWhenCloudIsEmpty() throws {
        let p = paths()
        try "local".write(to: p.localData, atomically: true, encoding: .utf8)
        let url = try SyncMigration.enable(p)
        #expect(url == p.cloudData)
        #expect(try String(contentsOf: p.cloudData, encoding: .utf8) == "local")
    }

    @Test func enableKeepsCloudDataAndBacksUpLocal() throws {
        let p = paths()
        try "local".write(to: p.localData, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: p.cloudData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cloud".write(to: p.cloudData, atomically: true, encoding: .utf8)

        _ = try SyncMigration.enable(p)

        #expect(try String(contentsOf: p.cloudData, encoding: .utf8) == "cloud")
        #expect(try String(contentsOf: p.localBackup, encoding: .utf8) == "local")
    }

    @Test func disableCopiesCloudDataBack() throws {
        let p = paths()
        try FileManager.default.createDirectory(at: p.cloudData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cloud".write(to: p.cloudData, atomically: true, encoding: .utf8)
        try "stale".write(to: p.localData, atomically: true, encoding: .utf8)

        let url = try SyncMigration.disable(p)

        #expect(url == p.localData)
        #expect(try String(contentsOf: p.localData, encoding: .utf8) == "cloud")
    }
}

@MainActor
@Suite struct StoreSyncTests {
    @Test func relocateLoadsTheOtherFile() {
        let a = tempDir().appendingPathComponent("a.json")
        let b = tempDir().appendingPathComponent("b.json")
        let other = TodoStore(fileURL: b, calendar: utc, now: { day(2026, 11, 2) })
        other.add("lives in b")

        let s = TodoStore(fileURL: a, calendar: utc, now: { day(2026, 11, 2) })
        s.add("lives in a")
        s.relocate(to: b)

        #expect(s.todos.map(\.title) == ["lives in b"])
    }

    @Test func externalWritesAreMergedBeforeTheNextChange() {
        let file = tempDir().appendingPathComponent("todos.json")
        let mac = TodoStore(fileURL: file, calendar: utc, now: { day(2026, 11, 2) })
        let otherMac = TodoStore(fileURL: file, calendar: utc, now: { day(2026, 11, 2) })

        otherMac.add("from the other mac")
        mac.add("from this mac")

        let reread = TodoStore(fileURL: file, calendar: utc, now: { day(2026, 11, 2) })
        #expect(Set(reread.todos.map(\.title)) == ["from the other mac", "from this mac"])
    }

    @Test func reloadIfChangedReportsChanges() {
        let file = tempDir().appendingPathComponent("todos.json")
        let mac = TodoStore(fileURL: file, calendar: utc, now: { day(2026, 11, 2) })
        #expect(!mac.reloadIfChangedExternally())
        TodoStore(fileURL: file, calendar: utc, now: { day(2026, 11, 2) }).add("x")
        #expect(mac.reloadIfChangedExternally())
        #expect(mac.todos.map(\.title) == ["x"])
    }

    @Test func digestIsWrittenOnSave() throws {
        let digest = tempDir().appendingPathComponent("tver-ka/Today.md")
        let s = TodoStore(fileURL: tempDir().appendingPathComponent("todos.json"), calendar: utc, now: { day(2026, 11, 2) })
        s.digestURL = digest
        s.add("gym")
        #expect(try String(contentsOf: digest, encoding: .utf8).contains("- gym · personal"))
    }
}

@Suite struct TodayDigestTests {
    @Test func rendersSectionsWithProjects() {
        let p = Project(name: "uni", color: .lime, createdAt: day(2026, 10, 1))
        var pri = todo("stats set", due: day(2026, 11, 2)); pri.isPriority = true; pri.rollCount = 3; pri.projectID = p.id
        var today = todo("gym", due: day(2026, 11, 2)); today.projectID = p.id
        var missed = todo("tix", due: day(2026, 10, 31), autoRoll: false); missed.projectID = p.id
        var done = todo("laundry", due: day(2026, 11, 2), done: true); done.projectID = p.id

        let md = TodayDigest.render(todos: [pri, today, missed, done], projects: [p], now: day(2026, 11, 2), calendar: utc)

        #expect(md.contains("# tver-ka · Mon, Nov 2"))
        #expect(md.contains("## Priority\n- stats set · uni · rolled ×3"))
        #expect(md.contains("## Today\n- gym · uni"))
        #expect(md.contains("## Missed\n- tix · uni · was due Sat, Oct 31"))
        #expect(!md.contains("laundry"))
    }

    @Test func emptyStateIsFriendly() {
        let md = TodayDigest.render(todos: [], projects: [], now: day(2026, 11, 2), calendar: utc)
        #expect(md.contains("all clear"))
    }
}
