import Foundation

public struct Todo: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    /// Owning project. Optional only so pre-project files decode; the store fills it in on load.
    public var projectID: UUID?
    public var createdAt: Date
    /// Start of the day the to-do is due.
    public var dueDate: Date
    public var isDone: Bool
    public var doneAt: Date?
    public var isPriority: Bool
    /// When on, an unfinished to-do slides to the next day and becomes priority.
    public var autoRoll: Bool
    /// How many days this to-do has been carried over.
    public var rollCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        projectID: UUID? = nil,
        createdAt: Date,
        dueDate: Date,
        isDone: Bool = false,
        doneAt: Date? = nil,
        isPriority: Bool = false,
        autoRoll: Bool = true,
        rollCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = isDone
        self.doneAt = doneAt
        self.isPriority = isPriority
        self.autoRoll = autoRoll
        self.rollCount = rollCount
    }
}

public enum TodoStatus: Equatable, Sendable {
    case done, priority, today, missed, upcoming
}

extension Todo {
    public func status(now: Date, calendar: Calendar) -> TodoStatus {
        if isDone { return .done }
        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: dueDate)
        if due < today { return .missed }
        if due > today { return .upcoming }
        return isPriority ? .priority : .today
    }
}
