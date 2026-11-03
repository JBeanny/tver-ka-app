import SwiftUI
import TverKaCore

enum Screen: Equatable {
    case today
    case done
}

struct RootView: View {
    @Environment(TodoStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var screen: Screen
    @State private var editing: Todo.ID?
    @State private var managingProjects: Bool
    @State private var settingUpPhone: Bool
    @State private var focusSettingsOpen: Bool
    @State private var updatesOpen: Bool
    private let projectsOpen: Bool

    init(
        screen: Screen = .today, editing: Todo.ID? = nil, managingProjects: Bool = false,
        projectsOpen: Bool = false, settingUpPhone: Bool = false, focusSettingsOpen: Bool = false,
        updatesOpen: Bool = false
    ) {
        _updatesOpen = State(initialValue: updatesOpen)
        _focusSettingsOpen = State(initialValue: focusSettingsOpen)
        _screen = State(initialValue: screen)
        _editing = State(initialValue: editing)
        _managingProjects = State(initialValue: managingProjects)
        _settingUpPhone = State(initialValue: settingUpPhone)
        self.projectsOpen = projectsOpen
    }

    var body: some View {
        let theme = Theme.of(scheme)
        ZStack {
            theme.bg.ignoresSafeArea()
            switch screen {
            case .today:
                TodayView(
                    theme: theme, showDone: { go(.done) },
                    edit: { id in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { editing = id } },
                    manageProjects: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { managingProjects = true } },
                    setUpPhone: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { settingUpPhone = true } },
                    focusSettings: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { focusSettingsOpen = true } },
                    checkUpdates: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { updatesOpen = true } },
                    projectsOpen: projectsOpen)
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .done:
                DoneDrawerView(theme: theme, back: { go(.today) })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if let id = editing, let todo = store.todo(id) {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                TaskOptionsView(theme: theme, todo: todo, close: close)
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
            }

            if managingProjects {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                ProjectsSheet(theme: theme, close: close)
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
            }

            if settingUpPhone {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                PhoneSetupView(theme: theme, close: close)
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
            }

            if focusSettingsOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                FocusSettingsView(theme: theme, close: close)
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
            }

            if updatesOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                UpdateSheet(theme: theme, close: close)
                    .padding(10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
            }
        }
        .frame(width: 360, height: 640)
        .onAppear { store.rollOver() }
    }

    private func go(_ next: Screen) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { screen = next }
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            editing = nil
            managingProjects = false
            settingUpPhone = false
            focusSettingsOpen = false
            updatesOpen = false
        }
    }
}
