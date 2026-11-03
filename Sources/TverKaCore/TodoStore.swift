import Foundation
import Observation

@MainActor
@Observable
public final class TodoStore {
    public private(set) var todos: [Todo] = []
    public private(set) var projects: [Project] = []
    /// Finished focus sessions from the last 60 days.
    public private(set) var focusLog: [FocusEntry] = []
    /// The selected project; also where new to-dos go while viewing all projects.
    public private(set) var activeProjectID: UUID
    /// When true the lists combine every project.
    public private(set) var showingAll = false
    /// The day the lists are computed for; advances in `rollOver()` so views refresh at midnight.
    public private(set) var currentDay: Date

    public let calendar: Calendar
    public private(set) var fileURL: URL
    /// When set, a Markdown digest of today is written here on every save (for the iPhone).
    public var digestURL: URL? {
        didSet { writeDigest() }
    }
    private let clock: @Sendable () -> Date
    /// Modification date of the data file as of our last read or write; anything newer came from elsewhere.
    private var knownModificationDate: Date?

    public init(fileURL: URL, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.clock = now
        self.currentDay = calendar.startOfDay(for: now())
        self.activeProjectID = UUID()
        load()
        if knownModificationDate == nil { save() }
        rollOver()
    }

    /// Points the store at another data file (e.g. iCloud Drive) and loads it.
    public func relocate(to url: URL) {
        fileURL = url
        knownModificationDate = nil
        projects = []
        todos = []
        focusLog = []
        load()
        if knownModificationDate == nil { save() }
        rollOver()
        writeDigest()
    }

    /// Reloads if the data file was changed by someone else (another Mac via iCloud).
    @discardableResult
    public func reloadIfChangedExternally() -> Bool {
        guard let modified = CoordinatedFile.modificationDate(fileURL), modified != knownModificationDate else {
            return false
        }
        load()
        writeDigest()
        return true
    }

    nonisolated public static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tver-ka", isDirectory: true)
        return dir.appendingPathComponent("todos.json")
    }

    public var now: Date { clock() }
    private var today: Date { calendar.startOfDay(for: now) }

    // MARK: - Projects

    public var activeProject: Project {
        projects.first { $0.id == activeProjectID } ?? projects[0]
    }

    public func selectProject(_ id: Project.ID) {
        reloadIfChangedExternally()
        guard projects.contains(where: { $0.id == id }) else { return }
        guard id != activeProjectID || showingAll else { return }
        activeProjectID = id
        showingAll = false
        save()
    }

    /// Picks where new to-dos go while viewing all projects, without leaving that view.
    public func setAddTarget(_ id: Project.ID) {
        reloadIfChangedExternally()
        guard projects.contains(where: { $0.id == id }), id != activeProjectID else { return }
        activeProjectID = id
        save()
    }

    public func showAll() {
        reloadIfChangedExternally()
        guard !showingAll else { return }
        showingAll = true
        save()
    }

    public func project(for todo: Todo) -> Project? {
        projects.first { $0.id == todo.projectID }
    }

    /// Creates a project, selects it and returns it. Blank names are ignored (returns the active project).
    @discardableResult
    public func addProject(_ name: String) -> Project {
        reloadIfChangedExternally()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activeProject }
        let used = Set(projects.map(\.color))
        let color = ProjectColor.allCases.first { !used.contains($0) }
            ?? ProjectColor.allCases[projects.count % ProjectColor.allCases.count]
        let project = Project(name: trimmed, color: color, createdAt: now)
        projects.append(project)
        activeProjectID = project.id
        showingAll = false
        save()
        return project
    }

    public func renameProject(_ id: Project.ID, _ name: String) {
        reloadIfChangedExternally()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].name = trimmed
        save()
    }

    public func setColor(_ id: Project.ID, _ color: ProjectColor) {
        reloadIfChangedExternally()
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].color = color
        save()
    }

    /// Deletes a project and all of its to-dos. The last project can't be deleted.
    public func deleteProject(_ id: Project.ID) {
        reloadIfChangedExternally()
        guard projects.count > 1, projects.contains(where: { $0.id == id }) else { return }
        projects.removeAll { $0.id == id }
        todos.removeAll { $0.projectID == id }
        if activeProjectID == id { activeProjectID = projects[0].id }
        save()
    }

    public func move(_ id: Todo.ID, to project: Project.ID) {
        guard projects.contains(where: { $0.id == project }) else { return }
        mutate(id) { $0.projectID = project }
    }

    public func openCount(in project: Project.ID) -> Int {
        todos.filter { $0.projectID == project && isOpenToday($0) }.count
    }

    // MARK: - Derived lists (scoped to the active project, or everything when showing all)

    private var projectTodos: [Todo] {
        showingAll ? todos : todos.filter { $0.projectID == activeProjectID }
    }

    private func items(_ status: TodoStatus) -> [Todo] {
        projectTodos.filter { $0.status(now: currentDay, calendar: calendar) == status }
    }

    private func isOpenToday(_ todo: Todo) -> Bool {
        let status = todo.status(now: currentDay, calendar: calendar)
        return status == .priority || status == .today
    }

    public var priorityItems: [Todo] { items(.priority).sorted { $0.rollCount > $1.rollCount } }
    public var todayItems: [Todo] { items(.today) }
    public var missedItems: [Todo] { items(.missed) }
    public var doneDays: [Stats.DoneDay] { Stats.doneByDay(projectTodos, calendar: calendar) }
    public var openCount: Int { priorityItems.count + todayItems.count }
    public var hasOpenPriority: Bool { !priorityItems.isEmpty }
    public var doneTodayCount: Int { doneDays.first { $0.day == today }?.items.count ?? 0 }
    public var doneTotalCount: Int { projectTodos.filter(\.isDone).count }
    public var doneThisWeekCount: Int {
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        return projectTodos.filter { ($0.doneAt ?? .distantPast) >= weekAgo }.count
    }
    public var rolledDoneThisWeekCount: Int {
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        return projectTodos.filter { ($0.doneAt ?? .distantPast) >= weekAgo && $0.rollCount > 0 }.count
    }

    // MARK: - Across all projects (menu bar, streak)

    public var totalOpenCount: Int { todos.filter(isOpenToday).count }
    public var anyOpenPriority: Bool {
        todos.contains { $0.status(now: currentDay, calendar: calendar) == .priority }
    }
    public var streak: Int { Stats.streak(todos, now: now, calendar: calendar) }

    public func todo(_ id: Todo.ID) -> Todo? { todos.first { $0.id == id } }

    // MARK: - Mutations

    public func add(_ title: String) {
        add(title, projectNamed: nil, priority: false)
    }

    /// Adds what was typed in the quick-add field, honoring `#project` and a trailing `!` like the iPhone inbox.
    public func addTyped(_ text: String) {
        guard let item = InboxParser.parse(text) else { return }
        add(item.title, projectNamed: item.projectName, priority: item.priority)
    }

    /// Adds a to-do to the project with this name (case-insensitive), or the active project if none matches.
    public func add(_ title: String, projectNamed name: String?, priority: Bool) {
        reloadIfChangedExternally()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let project = name.flatMap { n in
            projects.first { $0.name.compare(n, options: .caseInsensitive) == .orderedSame }
        }
        todos.append(Todo(
            title: trimmed, projectID: project?.id ?? activeProjectID, createdAt: now, dueDate: today,
            isPriority: priority))
        save()
    }

    public func toggleDone(_ id: Todo.ID) {
        mutate(id) { t in
            if t.isDone {
                t.isDone = false
                t.doneAt = nil
                t.dueDate = max(t.dueDate, today)
            } else {
                t.isDone = true
                t.doneAt = now
            }
        }
    }

    public func update(_ id: Todo.ID, title: String? = nil, autoRoll: Bool? = nil, isPriority: Bool? = nil) {
        mutate(id) { t in
            if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                t.title = title.trimmingCharacters(in: .whitespaces)
            }
            if let autoRoll { t.autoRoll = autoRoll }
            if let isPriority { t.isPriority = isPriority }
        }
    }

    /// A focus session finished: one more tomato for the to-do (if any) and for today.
    public func recordPomodoro(todoID: Todo.ID?, minutes: Int) {
        reloadIfChangedExternally()
        if let todoID, let i = todos.firstIndex(where: { $0.id == todoID }) {
            todos[i].pomodoros += 1
        }
        focusLog.append(FocusEntry(date: now, minutes: minutes, todoID: todoID))
        let cutoff = calendar.date(byAdding: .day, value: -60, to: today)!
        focusLog.removeAll { $0.date < cutoff }
        save()
    }

    public var pomodorosToday: Int {
        focusLog.filter { calendar.isDate($0.date, inSameDayAs: currentDay) }.count
    }

    public func bringToToday(_ id: Todo.ID) {
        mutate(id) { $0.dueDate = today }
    }

    public func delete(_ id: Todo.ID) {
        reloadIfChangedExternally()
        todos.removeAll { $0.id == id }
        save()
    }

    /// Call on launch, when the popover opens, on day change and on wake.
    public func rollOver() {
        if currentDay != today {
            currentDay = today
            writeDigest()
        }
        let rolled = Rollover.apply(to: todos, now: now, calendar: calendar)
        guard rolled != todos else { return }
        todos = rolled
        save()
    }

    private func mutate(_ id: Todo.ID, _ change: (inout Todo) -> Void) {
        reloadIfChangedExternally()
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        change(&todos[i])
        save()
    }

    // MARK: - Persistence

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = CoordinatedFile.read(fileURL) {
            // Only replace state on a successful decode, so a half-synced file never wipes anything.
            if let file = try? decoder.decode(SaveFile.self, from: data) {
                projects = file.projects
                todos = file.todos
                if let id = file.activeProjectID { activeProjectID = id }
                showingAll = file.showingAll ?? false
                focusLog = file.focusLog ?? []
                knownModificationDate = CoordinatedFile.modificationDate(fileURL)
            } else if let legacy = try? decoder.decode([Todo].self, from: data) {
                todos = legacy
                knownModificationDate = CoordinatedFile.modificationDate(fileURL)
            }
        }
        if projects.isEmpty {
            projects = [Project(name: "personal", color: .pink, createdAt: now)]
        }
        if !projects.contains(where: { $0.id == activeProjectID }) {
            activeProjectID = projects[0].id
        }
        // Adopt to-dos with no (or an unknown) project into the first one.
        let known = Set(projects.map(\.id))
        var adopted = false
        for i in todos.indices where todos[i].projectID.map(known.contains) != true {
            todos[i].projectID = projects[0].id
            adopted = true
        }
        if adopted { save() }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = SaveFile(
            projects: projects, activeProjectID: activeProjectID, showingAll: showingAll, todos: todos,
            focusLog: focusLog.isEmpty ? nil : focusLog)
        do {
            try CoordinatedFile.write(try encoder.encode(file), to: fileURL)
            knownModificationDate = CoordinatedFile.modificationDate(fileURL)
        } catch {
            NSLog("tver-ka: failed to save todos: \(error)")
        }
        writeDigest()
    }

    private func writeDigest() {
        guard let digestURL else { return }
        let text = TodayDigest.render(todos: todos, projects: projects, now: now, calendar: calendar)
        try? CoordinatedFile.write(Data(text.utf8), to: digestURL)
    }
}
