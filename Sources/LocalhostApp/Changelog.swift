import Foundation

struct ChangelogEntry: Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let items: [String]
}

enum Changelog {
    /// Newest first. Bump the version when you ship and add an entry.
    /// Date format: yyyy-MM-dd.
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "2026.05.05",
            date: "2026-05-05",
            items: [
                "Detect every $USER-owned listening port, not just node",
                "Show a green dot next to the port when an app is bound to multiple ports — click to see all of them with their command lines",
                "New \"Other ports in use\" section — surfaces dev servers you started outside OpenPort, with per-row stop",
                "Filter system processes (Tailscale, ssh tunnels, ControlCenter, etc.) out of \"Other ports\" so you can't accidentally kill them",
                "Settings → Action buttons: hide globe / copy / QR / terminal / VS Code / Finder per row",
                "Live logs viewer — modal sheet with search filter, auto-scroll, copy, and clear",
                "Cwd-based port matching: an app running on a different port than assigned now flips to detached and shows the actual port",
                "Settings: replaced checkboxes with macOS switches",
                "Settings and Help are now draggable, resizable windows instead of sheets",
                "Help redesigned with a sidebar, search, and 12 sections covering every feature"
            ]
        )
    ]

    static var latestVersion: String { entries.first?.version ?? "" }
}
