import AppKit
import SwiftUI
import TverKaCore

/// Walks through iCloud sync + installing the iPhone Shortcuts.
struct PhoneSetupView: View {
    @Environment(SyncController.self) private var sync
    var theme: Theme
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("add from iPhone")
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

            step(1, icon: "icloud", title: "sync with iCloud",
                 detail: sync.isAvailable
                    ? "keeps your to-dos in iCloud Drive › tver-ka"
                    : "turn on iCloud Drive in System Settings first",
                 fill: Theme.lime, textColor: Theme.ink, detailColor: Color(hex: 0x2E3A0A)) {
                Toggle("Sync with iCloud", isOn: Binding(get: { sync.isEnabled }, set: { sync.setEnabled($0) }))
                    .toggleStyle(StickerToggleStyle(onColor: Theme.ink))
                    .labelsHidden()
                    .disabled(!sync.isAvailable)
                    .opacity(sync.isAvailable ? 1 : 0.4)
            }

            step(2, icon: "square.on.square.badge.person.crop", title: "get the shortcut",
                 detail: "adds it to Shortcuts here, then it syncs to your iPhone",
                 fill: theme.bg, textColor: theme.text, detailColor: theme.sub) {
                EmptyView()
            }

            HStack(spacing: 8) {
                Button { open("Add to tver-ka") } label: {
                    Label("add to Shortcuts", systemImage: "plus")
                        .labelStyle(TightLabel())
                        .font(.rounded(13, .black))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .sticker(Theme.pink, line: theme.line, shadow: theme.shadow, radius: 13)
                }
                .buttonStyle(PressableStyle())
                Button { open("My tver-ka to-dos") } label: {
                    Text("+ list viewer")
                        .font(.rounded(13, .black))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .sticker(theme.card, line: theme.line, radius: 13)
                }
                .buttonStyle(PressableStyle())
                .help("Optional: a shortcut that shows today's to-dos on your iPhone")
            }

            VStack(alignment: .leading, spacing: 6) {
                tip("mic", "say \u{201C}Hey Siri, add to tver-ka\u{201D}")
                tip("number", "#work send invoice !  →  work, priority")
                tip("iphone", "put it on the Action button or home screen")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(Theme.butter, line: theme.line, radius: 14)

            Text(status)
                .font(.rounded(12, .heavy))
                .foregroundStyle(sync.lastError == nil ? theme.sub : Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 22, offset: 4)
    }

    private var status: String {
        if let error = sync.lastError { return error }
        guard sync.isEnabled else { return "turn on sync, then iPhone to-dos land here within a few seconds." }
        if let last = sync.lastImport {
            return "last iPhone to-do: \(last.formatted(.relative(presentation: .named)))"
        }
        return "synced ✓ waiting for your first iPhone to-do"
    }

    private func step<Trailing: View>(
        _ number: Int, icon: String, title: String, detail: String, fill: Color,
        textColor: Color, detailColor: Color, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.rounded(13, .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white))
                .overlay(Circle().strokeBorder(theme.line, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: icon)
                    .labelStyle(TightLabel())
                    .font(.rounded(15, .black))
                    .foregroundStyle(textColor)
                Text(detail)
                    .font(.rounded(12, .bold))
                    .foregroundStyle(detailColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(12)
        .sticker(fill, line: theme.line)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .frame(width: 16)
            Text(text).font(.rounded(12, .heavy))
        }
        .foregroundStyle(Theme.ink)
    }

    /// Opening a .shortcut file hands it to the Shortcuts app's import dialog.
    private func open(_ name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "shortcut") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "https://github.com/JBeanny/tver-ka-app/tree/main/Shortcuts") {
            NSWorkspace.shared.open(url)
        }
    }
}
