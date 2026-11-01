import AppKit

/// User-picked theme. Applied app-wide through `NSApp.appearance`, so SwiftUI's
/// `colorScheme`, text fields and menus all follow it.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Match system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    static var saved: Appearance {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Appearance.init) ?? .system
    }

    @MainActor func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
