import SwiftUI
import TverKaCore

/// "Check for Updates…": shows the state of the check and installs in place.
struct UpdateSheet: View {
    @Environment(UpdateController.self) private var updates
    var theme: Theme
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("updates")
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
                .disabled(updates.state == .installing)
                .accessibilityLabel("Close")
            }

            content

            HStack {
                Text("you have Tver Ka \(updates.currentVersion)")
                    .font(.rounded(12, .heavy))
                    .foregroundStyle(theme.sub)
                Spacer()
                Toggle("check daily", isOn: Binding(get: { updates.autoCheck }, set: { updates.setAutoCheck($0) }))
                    .toggleStyle(StickerToggleStyle(onColor: Theme.blue))
                    .scaleEffect(0.75)
                    .labelsHidden()
                Text("check daily")
                    .font(.rounded(12, .heavy))
                    .foregroundStyle(theme.sub)
            }
        }
        .padding(16)
        .sticker(theme.card, line: theme.line, shadow: theme.shadow, radius: 22, offset: 4)
        .task {
            if updates.state == .idle || updates.state == .upToDate { await updates.check() }
        }
    }

    @ViewBuilder private var content: some View {
        switch updates.state {
        case .idle, .checking:
            statusCard(icon: nil, title: "checking GitHub…", detail: "one sec", fill: theme.bg)
        case .upToDate:
            statusCard(icon: "checkmark.seal.fill", title: "you're up to date",
                       detail: "Tver Ka \(updates.currentVersion) is the latest.", fill: Theme.lime)
            button("check again", fill: theme.card) { Task { await updates.check() } }
        case .available:
            if let release = updates.release {
                available(release)
            }
        case .downloading:
            statusCard(icon: nil, title: "downloading…", detail: "grabbing the new version", fill: theme.bg)
        case .installing:
            statusCard(icon: nil, title: "installing…",
                       detail: "Tver Ka will close and reopen by itself in a moment", fill: Theme.butter)
        case .failed(let message):
            statusCard(icon: "exclamationmark.triangle.fill", title: "that didn't work", detail: message, fill: theme.bg)
            button("try again", fill: theme.card) { Task { await updates.check() } }
        }
    }

    private func available(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .black))
                    Text("Tver Ka \(release.version?.description ?? release.tagName) is out")
                        .font(.rounded(16, .black))
                }
                if !release.notes.isEmpty {
                    ScrollView {
                        Text(notes(release.notes))
                            .font(.rounded(12, .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 150)
                    .scrollIndicators(.automatic)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(Theme.lime, line: theme.line, shadow: theme.shadow)

            HStack(spacing: 8) {
                button("update & restart", fill: Theme.pink, shadow: true) { Task { await updates.install() } }
                if let page = release.htmlURL {
                    Link(destination: page) {
                        Text("on GitHub")
                            .font(.rounded(14, .black))
                            .foregroundStyle(theme.text)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .sticker(theme.card, line: theme.line, radius: 13)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Text("replaces this copy in place, your to-dos stay exactly as they are")
                .font(.rounded(12, .heavy))
                .foregroundStyle(theme.sub)
        }
    }

    private func notes(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }

    private func statusCard(icon: String?, title: String, detail: String, fill: Color) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon).font(.system(size: 22, weight: .bold))
            } else {
                ProgressView().controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rounded(15, .black))
                Text(detail)
                    .font(.rounded(12, .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(fill == theme.bg ? theme.text : Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill, line: theme.line)
    }

    private func button(_ title: String, fill: Color, shadow: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(14, .black))
                .foregroundStyle(fill == theme.card ? theme.text : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .sticker(fill, line: theme.line, shadow: shadow ? theme.shadow : nil, radius: 13)
        }
        .buttonStyle(PressableStyle())
    }
}
