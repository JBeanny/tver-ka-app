import SwiftUI
import TverKaCore

extension Theme {
    static func color(_ project: ProjectColor) -> Color {
        switch project {
        case .pink: pink
        case .lime: lime
        case .blue: blue
        case .butter: butter
        case .orange: Color(hex: 0xFF8A3D)
        case .purple: Color(hex: 0x9B5CFF)
        case .teal: Color(hex: 0x2EC4B6)
        }
    }
}

struct ProjectDot: View {
    var color: ProjectColor
    var line: Color
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .fill(Theme.color(color))
            .overlay(Circle().strokeBorder(line, lineWidth: 2))
            .frame(width: size, height: size)
    }
}

/// Overlapping dots in the first few project colors: stands for "all projects".
struct AllProjectsDot: View {
    @Environment(TodoStore.self) private var store
    var line: Color
    var size: CGFloat = 14

    var body: some View {
        let colors = Array(store.projects.prefix(3).map(\.color))
        HStack(spacing: -size * 0.45) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                ProjectDot(color: color, line: line, size: size)
            }
        }
    }
}

/// Small "● project" tag shown on rows while viewing all projects.
struct ProjectTag: View {
    var project: Project?
    var line: Color
    var textColor: Color

    var body: some View {
        if let project {
            HStack(spacing: 4) {
                ProjectDot(color: project.color, line: line, size: 9)
                Text(project.name)
                    .font(.rounded(11, .heavy))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
    }
}

/// The pill under the header that opens the project dropdown.
struct ProjectPill: View {
    @Environment(TodoStore.self) private var store
    var theme: Theme
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 7) {
                if store.showingAll {
                    AllProjectsDot(line: theme.line)
                } else {
                    ProjectDot(color: store.activeProject.color, line: theme.line)
                }
                Text(store.showingAll ? "all projects" : store.activeProject.name)
                    .font(.rounded(14, .black))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(theme.sub)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.leading, 9)
            .padding(.trailing, 11)
            .frame(height: 32)
            .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 99, offset: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Project: \(store.showingAll ? "all projects" : store.activeProject.name)")
        .accessibilityHint("Switch project")
    }
}

/// Sticker dropdown: pick a project, add one inline, or open the manager.
struct ProjectDropdown: View {
    @Environment(TodoStore.self) private var store
    var theme: Theme
    @Binding var isOpen: Bool
    var manage: () -> Void

    @State private var newName = ""
    @FocusState private var newFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(
                name: "all projects", open: store.totalOpenCount, selected: store.showingAll,
                select: { store.showAll() }
            ) {
                AllProjectsDot(line: theme.line, size: 12)
            }
            Rectangle().fill(theme.line.opacity(0.15)).frame(height: 1.5).padding(.vertical, 4)
            ForEach(store.projects) { project in
                row(
                    name: project.name, open: store.openCount(in: project.id),
                    selected: !store.showingAll && project.id == store.activeProjectID,
                    select: { store.selectProject(project.id) }
                ) {
                    ProjectDot(color: project.color, line: theme.line)
                }
            }

            Rectangle().fill(theme.line.opacity(0.15)).frame(height: 1.5).padding(.vertical, 4)

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(theme.sub)
                    .frame(width: 14)
                TextField("", text: $newName, prompt: Text("new project").foregroundStyle(theme.sub))
                    .textFieldStyle(.plain)
                    .font(.rounded(14, .bold))
                    .foregroundStyle(theme.text)
                    .focused($newFocused)
                    .onSubmit(addProject)
                    .accessibilityLabel("New project name")
            }
            .padding(.horizontal, 10)
            .frame(height: 34)

            Button {
                close()
                manage()
            } label: {
                Label("manage projects", systemImage: "slider.horizontal.3")
                    .labelStyle(TightLabel())
                    .font(.rounded(12, .black))
                    .foregroundStyle(theme.sub)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .frame(width: 240)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 16)
        .transition(.scale(scale: 0.92, anchor: .topLeading).combined(with: .opacity))
    }

    private func row<Dot: View>(
        name: String, open: Int, selected: Bool, select: @escaping () -> Void,
        @ViewBuilder dot: () -> Dot
    ) -> some View {
        Button {
            select()
            close()
        } label: {
            HStack(spacing: 9) {
                dot()
                Text(name)
                    .font(.rounded(14, .heavy))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if open > 0 {
                    Text("\(open)")
                        .font(.rounded(11, .black))
                        .foregroundStyle(theme.sub)
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(theme.text)
                    .opacity(selected ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? theme.bg : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addProject() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.addProject(newName)
        newName = ""
        close()
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOpen = false }
    }
}

/// Sheet for renaming, recoloring and deleting projects.
struct ProjectsSheet: View {
    @Environment(TodoStore.self) private var store
    var theme: Theme
    var close: () -> Void

    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("projects")
                    .font(.rounded(22, .black))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(theme.text)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }

            Text("tap a dot to change its color")
                .font(.rounded(12, .bold))
                .foregroundStyle(theme.sub)
                .padding(.top, -10)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.projects) { project in
                        ProjectEditRow(project: project, theme: theme, canDelete: store.projects.count > 1)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: 280)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, -4)

            HStack(spacing: 8) {
                TextField("", text: $newName, prompt: Text("new project…").foregroundStyle(theme.sub))
                    .textFieldStyle(.plain)
                    .font(.rounded(15, .bold))
                    .foregroundStyle(theme.text)
                    .onSubmit(add)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .sticker(theme.bg, line: theme.line, radius: 14)
                    .accessibilityLabel("New project name")
                Button(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .sticker(Theme.lime, line: theme.line, shadow: theme.shadow, radius: 14)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Add project")
            }
        }
        .padding(18)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 22, offset: 4)
    }

    private func add() {
        store.addProject(newName)
        newName = ""
    }
}

private struct ProjectEditRow: View {
    @Environment(TodoStore.self) private var store
    var project: Project
    var theme: Theme
    var canDelete: Bool

    @State private var name: String
    @State private var confirmingDelete = false

    init(project: Project, theme: Theme, canDelete: Bool) {
        self.project = project
        self.theme = theme
        self.canDelete = canDelete
        _name = State(initialValue: project.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                let all = ProjectColor.allCases
                let next = all[(all.firstIndex(of: project.color)! + 1) % all.count]
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { store.setColor(project.id, next) }
            } label: {
                ProjectDot(color: project.color, line: theme.line, size: 22)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Change color of \(project.name)")

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .font(.rounded(15, .heavy))
                .foregroundStyle(theme.text)
                .onChange(of: name) { _, new in store.renameProject(project.id, new) }
                .accessibilityLabel("Project name")

            Text("\(store.openCount(in: project.id)) open")
                .font(.rounded(11, .black))
                .foregroundStyle(theme.sub)
                .fixedSize()

            if canDelete {
                Button {
                    if confirmingDelete {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.deleteProject(project.id) }
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { confirmingDelete = true }
                    }
                } label: {
                    Group {
                        if confirmingDelete {
                            Text("delete all?")
                                .font(.rounded(11, .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .sticker(Theme.danger, line: theme.line, radius: 99, lineWidth: 2)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.danger)
                        }
                    }
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(confirmingDelete ? "Confirm: delete \(project.name) and its to-dos" : "Delete \(project.name)")
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .sticker(theme.bg, line: theme.line, radius: 14, lineWidth: 2)
        .onChange(of: project.id) { _, _ in confirmingDelete = false }
    }
}
