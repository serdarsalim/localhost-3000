import AppKit
import SwiftTerm

enum TerminalThemeID: String, CaseIterable, Identifiable {
    case system
    case dark
    case light
    case solarizedDark = "solarized-dark"
    case solarizedLight = "solarized-light"
    case dracula
    case nord

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Match system"
        case .dark: return "Dark"
        case .light: return "Light"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        }
    }
}

struct TerminalAppearance {
    let background: NSColor
    let foreground: NSColor
    let cursor: NSColor
    let fontSize: CGFloat

    static func fromDefaults() -> TerminalAppearance {
        let raw = UserDefaults.standard.string(forKey: "terminalTheme") ?? TerminalThemeID.system.rawValue
        let theme = TerminalThemeID(rawValue: raw) ?? .system
        let stored = UserDefaults.standard.double(forKey: "terminalFontSize")
        let size: CGFloat = stored > 0 ? CGFloat(stored) : 13
        return TerminalAppearance(theme: theme, fontSize: size)
    }

    init(theme: TerminalThemeID, fontSize: CGFloat) {
        self.fontSize = fontSize

        let resolved: TerminalThemeID
        if theme == .system {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            resolved = isDark ? .dark : .light
        } else {
            resolved = theme
        }

        switch resolved {
        case .dark, .system:
            background = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
            foreground = NSColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1)
            cursor = foreground
        case .light:
            background = NSColor.white
            foreground = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
            cursor = foreground
        case .solarizedDark:
            background = NSColor(srgbRed: 0.0,  green: 0.168, blue: 0.211, alpha: 1) // base03
            foreground = NSColor(srgbRed: 0.514, green: 0.580, blue: 0.588, alpha: 1) // base0
            cursor = NSColor(srgbRed: 0.710, green: 0.537, blue: 0.0, alpha: 1)        // yellow
        case .solarizedLight:
            background = NSColor(srgbRed: 0.992, green: 0.964, blue: 0.890, alpha: 1) // base3
            foreground = NSColor(srgbRed: 0.396, green: 0.482, blue: 0.514, alpha: 1) // base00
            cursor = NSColor(srgbRed: 0.710, green: 0.537, blue: 0.0, alpha: 1)
        case .dracula:
            background = NSColor(srgbRed: 0.157, green: 0.165, blue: 0.212, alpha: 1) // #282a36
            foreground = NSColor(srgbRed: 0.972, green: 0.972, blue: 0.949, alpha: 1) // #f8f8f2
            cursor = NSColor(srgbRed: 1.0, green: 0.474, blue: 0.776, alpha: 1)        // pink
        case .nord:
            background = NSColor(srgbRed: 0.180, green: 0.204, blue: 0.251, alpha: 1) // #2e3440
            foreground = NSColor(srgbRed: 0.851, green: 0.871, blue: 0.914, alpha: 1) // #d8dee9
            cursor = NSColor(srgbRed: 0.533, green: 0.752, blue: 0.816, alpha: 1)     // #88c0d0
        }
    }

    @MainActor
    func apply(to view: LocalProcessTerminalView) {
        view.nativeBackgroundColor = background
        view.nativeForegroundColor = foreground
        view.caretColor = cursor
        view.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
