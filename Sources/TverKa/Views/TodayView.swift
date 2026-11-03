import ServiceManagement
import SwiftUI
import TverKaCore

struct TodayView: View {
    @Environment(TodoStore.self) private var store
    @Environment(SyncController.self) private var sync
    var theme: Theme
    var showDone: () -> Void
    var edit: (Todo.ID) -> Void
    var manageProjects: () -> Void
    var setUpPhone: () -> Void

    @State private var draft = ""
    @State var projectsOpen = false
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @FocusState private var addFocused: Bool

    private var isEmpty: Bool {
        store.openCount == 0 && store.missedItems.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            projectRow
            if !isEmpty { greeting }
            quickAdd
            if isEmpty {
                EmptyStateView(theme: theme, doneToday: store.doneTodayCount)
            } else {
                list
                progress
            }
        }
        .padding(18)
        .onAppear { addFocused = true }
        .overlayPreferenceValue(PillAnchorKey.self) { anchor in
            GeometryReader { geo in
                if projectsOpen, let anchor {
                    let pill = geo[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { projectsOpen = false }
                            }
                        ProjectDropdown(theme: theme, isOpen: $projectsOpen, manage: manageProjects)
                            .offset(x: pill.minX, y: pill.maxY + 8)
                    }
                }
            }
        }
    }

    private var projectRow: some View {
        HStack {
            ProjectPill(theme: theme, isOpen: $projectsOpen)
                .anchorPreference(key: PillAnchorKey.self, value: .bounds) { $0 }
            Spacer()
            if sync.isEnabled {
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.sub)
                    .help("Synced with iCloud Drive")
                    .accessibilityLabel("Synced with iCloud")
            }
            Text(store.currentDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                .font(.rounded(12, .heavy))
                .tracking(1.2)
                .foregroundStyle(theme.sub)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Wordmark(theme: theme)
            Spacer()
            if store.streak > 0 {
                StickerBadge(
                    text: "\(store.streak) day streak", icon: "flame.fill", fill: Theme.lime,
                    line: theme.line, tilt: -3, size: 13, capsule: true)
            }
            StickerIconButton(
                systemImage: "checkmark.rectangle.stack", label: "Show done to-dos",
                theme: theme, badge: store.doneTotalCount, action: showDone)
            settingsMenu
        }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle("Launch at login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        NSLog("tver-ka: launch at login failed: \(error)")
                    }
                }))
            Toggle("Sync with iCloud", isOn: Binding(get: { sync.isEnabled }, set: { sync.setEnabled($0) }))
                .disabled(!sync.isAvailable)
            Button("Add from iPhone…", action: setUpPhone)
            Divider()
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            Divider()
            Button("Quit tver-ka") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(theme.sub)
                .frame(width: 24, height: 40)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Settings")
        .onChange(of: appearance) { _, new in new.apply() }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.missedItems.isEmpty ? "what's the move today?" : "one slipped thru, no stress")
                .font(.rounded(22, .black))
                .foregroundStyle(theme.text)
        }
    }

    // MARK: - Quick add

    private var quickAdd: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if store.showingAll {
                    AddTargetMenu(theme: theme)
                }
                TextField("", text: $draft, prompt: Text("drop a to-do…").foregroundStyle(theme.sub))
                    .textFieldStyle(.plain)
                    .font(.rounded(15, .bold))
                    .foregroundStyle(theme.text)
                    .focused($addFocused)
                    .onSubmit(add)
                    .accessibilityLabel("New to-do")
            }
            .padding(.leading, store.showingAll ? 7 : 14)
            .padding(.trailing, 14)
            .frame(height: 44)
            .sticker(theme.card, line: theme.line, radius: 14)
            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .sticker(Theme.pink, line: theme.line, shadow: theme.shadow, radius: 14)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add to-do")
        }
    }

    private func add() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.addTyped(draft) }
        draft = ""
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !store.missedItems.isEmpty {
                    section {
                        StickerBadge(
                            text: "MISSED", fill: theme.missedFill, textColor: theme.missedText,
                            line: theme.missedLine, size: 12, capsule: true)
                        Text("auto-roll was off for these")
                            .font(.rounded(12, .bold))
                            .foregroundStyle(theme.sub)
                    } rows: {
                        ForEach(store.missedItems) { MissedCard(todo: $0, theme: theme) }
                    }
                }
                if !store.priorityItems.isEmpty {
                    section {
                        StickerBadge(
                            text: "PRIORITY · CARRIED OVER", icon: "flame.fill", fill: Theme.pink,
                            line: theme.line, size: 12, capsule: true)
                        Spacer()
                        count(store.priorityItems.count)
                    } rows: {
                        ForEach(store.priorityItems) { todo in
                            TodoRow(todo: todo, theme: theme, edit: { edit(todo.id) })
                        }
                    }
                }
                if !store.todayItems.isEmpty {
                    section {
                        Text("TODAY")
                            .font(.rounded(12, .black))
                            .tracking(1.2)
                            .foregroundStyle(theme.sub)
                        Spacer()
                        count(store.todayItems.count)
                    } rows: {
                        ForEach(store.todayItems) { todo in
                            TodoRow(todo: todo, theme: theme, edit: { edit(todo.id) })
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.never)
        .padding(.horizontal, -6)
    }

    private func section<H: View, R: View>(
        @ViewBuilder header: () -> H, @ViewBuilder rows: () -> R
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) { header() }
            rows()
        }
    }

    private func count(_ n: Int) -> some View {
        Text("\(n)").font(.rounded(13, .black)).foregroundStyle(theme.sub)
    }

    // MARK: - Progress

    private var progress: some View {
        let done = store.doneTodayCount
        let total = done + store.openCount
        let ratio = total == 0 ? 0 : Double(done) / Double(total)
        return VStack(spacing: 6) {
            HStack {
                Text("\(done) of \(total) done")
                Spacer()
                Text(ratio >= 1 ? "main character energy" : ratio >= 0.5 ? "halfway, slay" : "we move")
            }
            .font(.rounded(12, .black))
            .foregroundStyle(theme.sub)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.card)
                    Rectangle()
                        .fill(Theme.lime)
                        .frame(width: geo.size.width * ratio)
                        .overlay(alignment: .trailing) {
                            if ratio > 0 && ratio < 1 { Rectangle().fill(theme.line).frame(width: 2.5) }
                        }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(theme.line, lineWidth: 2.5))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: ratio)
            }
            .frame(height: 14)
        }
    }
}

private struct PillAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
