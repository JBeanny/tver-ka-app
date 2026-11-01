import SwiftUI
import TverKaCore

struct TaskOptionsView: View {
    @Environment(TodoStore.self) private var store
    var theme: Theme
    var todo: Todo
    var close: () -> Void

    @State private var title: String
    @State private var autoRoll: Bool
    @State private var isPriority: Bool
    @State private var projectID: UUID?

    init(theme: Theme, todo: Todo, close: @escaping () -> Void) {
        self.theme = theme
        self.todo = todo
        self.close = close
        _title = State(initialValue: todo.title)
        _autoRoll = State(initialValue: todo.autoRoll)
        _isPriority = State(initialValue: todo.isPriority)
        _projectID = State(initialValue: todo.projectID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                if isPriority {
                    StickerBadge(text: "PRIORITY", fill: Theme.pink, line: theme.line, tilt: -3, capsule: true)
                }
                if todo.rollCount > 0 {
                    StickerBadge(text: "rolled ×\(todo.rollCount)", fill: Theme.blue, textColor: .white, line: theme.line, tilt: 2)
                }
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TO-DO")
                        .font(.rounded(12, .black))
                        .tracking(1.2)
                        .foregroundStyle(theme.sub)
                    Spacer()
                    projectPicker
                }
                TextField("", text: $title)
                    .textFieldStyle(.plain)
                    .font(.rounded(16, .heavy))
                    .foregroundStyle(theme.text)
                    .onSubmit(save)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .sticker(theme.bg, line: theme.line, radius: 14)
                    .accessibilityLabel("To-do title")
            }

            optionRow(
                icon: "repeat", title: "auto-roll",
                detail: "not done by midnight? it slides to tomorrow and gets the priority sticker",
                fill: Theme.lime, detailColor: Color(hex: 0x2E3A0A), textColor: Theme.ink,
                toggle: Toggle("Auto-roll", isOn: $autoRoll).toggleStyle(StickerToggleStyle(onColor: Theme.ink)))

            optionRow(
                icon: "flame", title: "priority", detail: "pinned to the top until it's done",
                fill: theme.bg, detailColor: theme.sub, textColor: theme.text,
                toggle: Toggle("Priority", isOn: $isPriority).toggleStyle(StickerToggleStyle(onColor: Theme.pink)))

            HStack(spacing: 10) {
                Button {
                    close()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.delete(todo.id) }
                } label: {
                    Label("yeet it", systemImage: "trash")
                        .labelStyle(TightLabel())
                        .fixedSize()
                        .font(.rounded(15, .black))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .sticker(.white, line: theme.line, radius: 14)
                }
                .buttonStyle(PressableStyle())

                Button(action: save) {
                    Text("save")
                        .font(.rounded(15, .black))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .sticker(Theme.pink, line: theme.line, shadow: theme.shadow, radius: 14)
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 22, offset: 4)
    }

    private func optionRow<T: View>(
        icon: String, title: String, detail: String, fill: Color,
        detailColor: Color, textColor: Color, toggle: T
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(textColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rounded(15, .black)).foregroundStyle(textColor)
                Text(detail)
                    .font(.rounded(12, .bold))
                    .foregroundStyle(detailColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            toggle.labelsHidden()
        }
        .padding(12)
        .sticker(fill, line: theme.line)
    }

    private var projectPicker: some View {
        let current = store.projects.first { $0.id == projectID } ?? store.activeProject
        return Menu {
            ForEach(store.projects) { project in
                Button {
                    projectID = project.id
                } label: {
                    if project.id == current.id {
                        Label(project.name, systemImage: "checkmark")
                    } else {
                        Text(project.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                ProjectDot(color: current.color, line: theme.line, size: 11)
                Text(current.name)
                    .font(.rounded(12, .black))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(theme.sub)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .sticker(theme.bg, line: theme.line, radius: 99, lineWidth: 2)
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Move to project, currently \(current.name)")
    }

    private func save() {
        if let projectID, projectID != todo.projectID { store.move(todo.id, to: projectID) }
        store.update(todo.id, title: title, autoRoll: autoRoll, isPriority: isPriority)
        close()
    }
}
