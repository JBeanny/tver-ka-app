import Foundation

public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: ProjectColor
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, color: ProjectColor, createdAt: Date) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}

/// Sticker palette for project dots; the app maps each case to a real color.
public enum ProjectColor: String, Codable, CaseIterable, Sendable {
    case pink, lime, blue, butter, orange, purple, teal
}

/// On-disk shape of `todos.json`. Version 1 was a bare `[Todo]` array.
struct SaveFile: Codable {
    var version = 2
    var projects: [Project]
    var activeProjectID: UUID?
    var showingAll: Bool?
    var todos: [Todo]
    var focusLog: [FocusEntry]?
}
