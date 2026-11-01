import Foundation
import Testing
@testable import TverKaCore

@MainActor
@Suite struct ProjectTests {
    func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tverka-\(UUID().uuidString).json")
    }

    func store(_ file: URL, _ now: Date = day(2026, 11, 1)) -> TodoStore {
        TodoStore(fileURL: file, calendar: utc, now: { now })
    }

    @Test func freshStoreHasOneDefaultProjectSelected() {
        let s = store(tempFile())
        #expect(s.projects.map(\.name) == ["personal"])
        #expect(s.activeProject.id == s.projects[0].id)
    }

    @Test func legacyTodoArrayFileMigratesIntoDefaultProject() throws {
        let file = tempFile()
        let legacy = [todo("old one", due: day(2026, 11, 1))]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(legacy).write(to: file)

        let s = store(file)
        #expect(s.projects.count == 1)
        #expect(s.todayItems.map(\.title) == ["old one"])
        #expect(s.todos[0].projectID == s.projects[0].id)
    }

    @Test func newTodosGoIntoTheActiveProjectAndListsAreScoped() {
        let s = store(tempFile())
        s.add("personal thing")
        let work = s.addProject("work")
        #expect(s.activeProject.id == work.id)
        s.add("ship the deck")

        #expect(s.todayItems.map(\.title) == ["ship the deck"])
        s.selectProject(s.projects[0].id)
        #expect(s.todayItems.map(\.title) == ["personal thing"])
    }

    @Test func menuBarCountsSpanAllProjects() {
        let s = store(tempFile())
        s.add("a")
        s.addProject("work")
        s.add("b")
        s.add("c")
        #expect(s.openCount == 2)
        #expect(s.totalOpenCount == 3)
        #expect(s.openCount(in: s.projects[0].id) == 1)
    }

    @Test func priorityDotLightsUpForAnyProject() {
        let file = tempFile()
        let first = store(file, day(2026, 10, 31))
        first.add("rolls over")
        first.addProject("work")

        let next = store(file)
        #expect(next.activeProject.name == "work")
        #expect(!next.hasOpenPriority)
        #expect(next.anyOpenPriority)
    }

    @Test func activeProjectAndProjectsPersist() {
        let file = tempFile()
        let first = store(file)
        let work = first.addProject("work")
        first.setColor(work.id, .blue)

        let next = store(file)
        #expect(next.projects.map(\.name) == ["personal", "work"])
        #expect(next.activeProject.id == work.id)
        #expect(next.activeProject.color == .blue)
    }

    @Test func blankProjectNamesAreIgnoredAndRenameTrims() {
        let s = store(tempFile())
        let before = s.projects.count
        s.addProject("   ")
        #expect(s.projects.count == before)
        s.renameProject(s.projects[0].id, "  side quests ")
        #expect(s.projects[0].name == "side quests")
        s.renameProject(s.projects[0].id, " ")
        #expect(s.projects[0].name == "side quests")
    }

    @Test func deletingAProjectRemovesItsTodosAndSelectsAnother() {
        let s = store(tempFile())
        s.add("keep me")
        let work = s.addProject("work")
        s.add("goes away")
        s.deleteProject(work.id)

        #expect(s.projects.map(\.name) == ["personal"])
        #expect(s.todos.map(\.title) == ["keep me"])
        #expect(s.activeProject.name == "personal")
    }

    @Test func theLastProjectCannotBeDeleted() {
        let s = store(tempFile())
        s.deleteProject(s.projects[0].id)
        #expect(s.projects.count == 1)
    }

    @Test func movingATodoToAnotherProject() {
        let s = store(tempFile())
        s.add("misfiled")
        let id = s.todos[0].id
        let work = s.addProject("work")
        s.selectProject(s.projects[0].id)
        s.move(id, to: work.id)
        #expect(s.todayItems.isEmpty)
        s.selectProject(work.id)
        #expect(s.todayItems.map(\.title) == ["misfiled"])
    }

    @Test func newProjectsCycleThroughColors() {
        let s = store(tempFile())
        let a = s.addProject("a")
        let b = s.addProject("b")
        #expect(a.color != b.color)
    }

    @Test func allProjectsViewCombinesEveryProject() {
        let s = store(tempFile())
        s.add("personal thing")
        s.addProject("work")
        s.add("work thing")
        s.showAll()

        #expect(s.showingAll)
        #expect(Set(s.todayItems.map(\.title)) == ["personal thing", "work thing"])
        #expect(s.openCount == 2)
    }

    @Test func addingWhileViewingAllGoesToLastUsedProject() {
        let s = store(tempFile())
        let work = s.addProject("work")
        s.showAll()
        s.add("from all view")
        #expect(s.todos.last?.projectID == work.id)
        #expect(s.activeProject.id == work.id)
    }

    @Test func selectingAProjectLeavesAllView() {
        let s = store(tempFile())
        s.showAll()
        s.selectProject(s.projects[0].id)
        #expect(!s.showingAll)
    }

    @Test func selectingTheActiveProjectFromAllViewStillLeavesIt() {
        let s = store(tempFile())
        s.showAll()
        s.selectProject(s.activeProjectID)
        #expect(!s.showingAll)
    }

    @Test func allViewPersists() {
        let file = tempFile()
        store(file).showAll()
        #expect(store(file).showingAll)
    }

    @Test func doneAndMissedCombineInAllView() {
        let file = tempFile()
        let first = store(file, day(2026, 10, 31))
        first.add("missed one")
        first.update(first.todos[0].id, autoRoll: false)
        first.addProject("work")
        first.add("done one")
        first.toggleDone(first.todos[1].id)

        let next = store(file)
        next.showAll()
        #expect(next.missedItems.map(\.title) == ["missed one"])
        #expect(next.doneTotalCount == 1)
    }

    @Test func projectLookup() {
        let s = store(tempFile())
        s.add("x")
        #expect(s.project(for: s.todos[0])?.name == "personal")
    }
}
