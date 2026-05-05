import SwiftUI

struct HelpSection: Identifiable {
    var id: String { title }
    let title: String
    let symbol: String
    let body: AnyView

    init(_ title: String, symbol: String, @ViewBuilder body: () -> some View) {
        self.title = title
        self.symbol = symbol
        self.body = AnyView(body())
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selected: String?

    private var sections: [HelpSection] {
        HelpContent.sections
    }

    private var filteredSections: [HelpSection] {
        guard !search.isEmpty else { return sections }
        let q = search.lowercased()
        return sections.filter { section in
            if section.title.lowercased().contains(q) { return true }
            return HelpContent.searchText(for: section.title).lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                content
            }
            Divider()
            footer
        }
        .frame(minWidth: 820, idealWidth: 980, maxWidth: .infinity,
               minHeight: 520, idealHeight: 680, maxHeight: .infinity)
        .onAppear {
            if selected == nil { selected = sections.first?.id }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("OpenPort — Help")
                .font(.headline)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search help", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(filteredSections) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selected == section.id,
                        action: { selected = section.id }
                    )
                }
                if filteredSections.isEmpty {
                    Text("No matches")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                }
            }
            .padding(10)
        }
        .frame(width: 240)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let current = filteredSections.first(where: { $0.id == selected }) ?? filteredSections.first {
                    HStack(spacing: 10) {
                        Image(systemName: current.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(current.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.bottom, 8)
                    current.body
                } else {
                    Text("Try a different search term.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

@MainActor
private struct SidebarRow: View {
    let section: HelpSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var background: Color {
        if isSelected { return Color.accentColor }
        if isHovered { return Color.primary.opacity(0.08) }
        return Color.clear
    }

    private var foreground: Color {
        isSelected ? .white : .primary
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.symbol)
                .frame(width: 18)
                .foregroundStyle(isSelected ? Color.white : .secondary)
            Text(section.title)
                .foregroundStyle(foreground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .onTapGesture { action() }
    }
}

@MainActor
private enum HelpContent {
    static let sections: [HelpSection] = [
        HelpSection("Getting started", symbol: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                helpText("OpenPort scans a folder of web projects and lets you start, stop, and inspect their dev servers without touching the terminal. Any project with a `dev` or `dev:frontend` script in its `package.json` shows up as a row.")
                helpText("**First run:** click *Change Folder* in the footer (folder-with-gear icon) and pick the folder that contains your projects — for example `~/my-portfolio` if your apps live at `~/my-portfolio/foo`, `~/my-portfolio/bar`, etc. The choice persists.")
                helpText("After that, hit Play on any row to start it, then the globe icon to open it in your browser.")
            }
        },

        HelpSection("Main list", symbol: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                helpRow("Play / Stop", "Starts or stops the dev server. Stop also kills any extra ports the same project bound to (backend, HMR, debug).")
                helpRow("App name", "The project's folder name. When go/ links are enabled, click the alias next to it to edit.")
                helpRow("Port", "Click when stopped to type a new port. Scroll the wheel over the field to nudge ±1. Orange = something else is on this port; clicking play offers a kill-and-retry prompt.")
                helpRow("Multi-port dot", "Green dot next to the port appears when the app is bound to multiple ports OR has a backend script. Click to see every port and its full command.")
                helpRow("Git", "Clean = no uncommitted changes. Orange count = how many uncommitted files.")
                helpRow("Search", "The top-right search field filters the list as you type.")
            }
        },

        HelpSection("Action buttons", symbol: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: 10) {
                helpText("Each row has a row of icons on the right. Hide any of them in **Settings → Action buttons**.")
                helpRow("Globe", "Open http://localhost:PORT in your browser. Running only.")
                helpRow("Copy", "Copy the LAN URL (e.g. http://192.168.1.42:3001) for opening on phones / other devices on the same Wi-Fi. Running only.")
                helpRow("QR code", "Popover with a QR for the LAN URL. Scan with your phone. Running only.")
                helpRow("Logs (🔍)", "Opens a resizable modal with the app's stdout + stderr, updated every 500ms. Has search, auto-scroll, copy, and clear. Running only.")
                helpRow("Terminal", "Open the project folder in Terminal.")
                helpRow("VS Code", "Open the project in VS Code.")
                helpRow("Finder", "Open the project in Finder.")
            }
        },

        HelpSection("Detected ports", symbol: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 12) {
                helpText("OpenPort detects what's actually listening, not just what it started. On every refresh it scans your user's listening TCP sockets and matches them back to projects by working directory.")
                helpText("**Detached state:** if you started an app in a terminal (or it's still running from before), the row flips to detached on refresh — the orange port number switches to the *actual* port it's bound to, and the stop button works on that real process. Your assigned port stays saved underneath, so the next Play uses it again.")
                helpText("**Multiple ports:** common for apps that run a frontend + backend (Next + Convex) or use HMR / inspector ports. The green dot next to the port column tells you there's more — click for the full list with command lines.")
            }
        },

        HelpSection("Other ports in use", symbol: "questionmark.circle") {
            VStack(alignment: .leading, spacing: 12) {
                helpText("A separate section appears at the bottom of the list when something is listening that doesn't match a known project — usually a dev server you started in a terminal from a folder outside your portfolio root.")
                helpText("Each row shows the cwd, port, and full command. The stop button signals SIGTERM to the PID. When the cwd is outside your portfolio root, you'll get a confirmation dialog before killing — to avoid wiping out an unrelated session.")
                helpText("**System processes are filtered out** so you can't accidentally kill them: Tailscale, ssh tunnels, ControlCenter, rapportd (Continuity), Mac apps (Text Blaze, MEGAsync), OpenPort itself, and anything in /System, /usr, /Library, /Applications.")
                helpText("**Stop All never touches this section** — it only stops projects in the main list.")
            }
        },

        HelpSection("Live logs viewer", symbol: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: 10) {
                helpText("Click the magnifier-on-document icon on any running row to open a resizable modal showing the app's combined stdout + stderr stream.")
                helpRow("Search", "Filter lines as you type. Footer shows match count.")
                helpRow("Auto-scroll", "Toggle in the footer. On = jumps to newest. Off = stays put while logs stream.")
                helpRow("Copy", "Copy the entire visible buffer to clipboard.")
                helpRow("Clear", "Wipe the in-memory buffer for that app.")
                helpRow("Buffer", "Capped at 1000 lines per app to bound memory.")
                helpText("**Limitation:** only apps started by OpenPort have a buffer — orphan / detached processes can't be tapped because we don't own their output pipes. To debug one, stop it and start it from inside OpenPort.")
            }
        },

        HelpSection("Footer", symbol: "rectangle.bottomthird.inset.filled") {
            VStack(alignment: .leading, spacing: 10) {
                helpRow("Stop All", "Stops every dev server in the main list, including their multi-port siblings. Never touches the Other ports section.")
                helpRow("Refresh (⌘R)", "Re-scans your folder, port detection, and git status.")
                helpRow("Change Folder", "Pick a different portfolio root.")
                helpRow("Help / Settings", "This window / preferences.")
                helpRow("Sun / Moon", "Toggle light / dark theme.")
                helpRow("What's new", "Shows a blue dot when there are app changes you haven't seen yet. Click to view; it disappears once dismissed. Always reachable from Settings → What's new or the menu bar.")
            }
        },

        HelpSection("Settings", symbol: "gearshape") {
            VStack(alignment: .leading, spacing: 10) {
                helpRow("Launch at startup", "Auto-launch OpenPort when you log in.")
                helpRow("Menu bar quick launch", "Adds a network icon to the macOS menu bar with start/stop controls per app.")
                helpRow("go/ links", "See its own help section.")
                helpRow("Action buttons", "Toggle each of the row's icons (browser, copy, QR, logs, terminal, VS Code, Finder) on or off. Hide whatever you don't use.")
                helpRow("What's new", "Re-open the changelog any time from the bottom of Settings.")
            }
        },

        HelpSection("go/ links", symbol: "link") {
            VStack(alignment: .leading, spacing: 12) {
                helpText("Type `http://go/<alias>` in any browser to open the matching app. Set an alias by clicking the go/ badge next to an app name when go/ links are enabled.")
                helpText("**One-time setup:** OpenPort adds a `127.0.0.1 go` line to /etc/hosts and installs a tiny launchd port-80 forwarder so unprefixed URLs work in every browser. Asks for your password once via the standard macOS prompt.")
                helpText("Disable any time in Settings — the proxy stops, but the hosts entry stays until you remove it manually.")
            }
        },

        HelpSection("Menu bar", symbol: "menubar.dock.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                helpText("Enable **Menu bar quick launch** in Settings to add a network icon to the macOS menu bar.")
                helpText("Click it for a list of all your apps, each with running state and a quick start/stop. Below the list:")
                helpRow("Show OpenPort", "Brings the main window to the front.")
                helpRow("What's new", "Opens the changelog directly.")
                helpRow("Quit", "Quit the app entirely (⌘Q).")
            }
        },

        HelpSection("Network URL", symbol: "wifi") {
            VStack(alignment: .leading, spacing: 12) {
                helpText("The copy icon copies a LAN URL like `http://192.168.1.42:3001`. Paste it into any device on the same Wi-Fi to preview your project remotely.")
                helpText("If the other device can't connect, add `--hostname 0.0.0.0` to the dev script in `package.json` — many frameworks (including Next.js) bind to localhost only by default.")
            }
        },

        HelpSection("Troubleshooting", symbol: "wrench.and.screwdriver") {
            VStack(alignment: .leading, spacing: 10) {
                helpRow("No apps found", "Projects need a `dev` or `dev:frontend` script in package.json, and you must pick the folder that contains them as the portfolio root.")
                helpRow("App won't start", "Check Node/npm. With nvm, set a default version: `nvm alias default <version>`. The Live logs button (🔍) shows the actual error message.")
                helpRow("Port already in use", "Change the port, or click play and accept the kill-and-retry prompt.")
                helpRow("Logs button is missing", "Only appears for apps started in OpenPort. Stop the terminal copy and re-start from here to capture output.")
                helpRow("Detected port doesn't match", "OpenPort matches by cwd. If the cwd reported by lsof doesn't equal your portfolio path exactly (symlinks, subfolders), it'll appear in *Other ports* instead of attaching to the row.")
                helpRow("Unidentified developer", "Right-click the app → Open → Open. macOS asks once, then trusts it.")
            }
        }
    ]

    /// Plain-text snapshot of section content for searching.
    static func searchText(for sectionTitle: String) -> String {
        searchIndex[sectionTitle] ?? ""
    }

    private static let searchIndex: [String: String] = [
        "Getting started": "scans folder web projects start stop inspect dev servers package.json first run change folder portfolio root",
        "Main list": "play stop dev server kills extra ports backend HMR debug app name go alias port click type new wheel nudge orange kill retry multi-port dot green backend script git clean uncommitted search filter",
        "Action buttons": "globe browser localhost copy LAN URL network 192 wifi devices QR code popover scan phone logs magnifier stdout stderr 500ms search auto-scroll terminal VS Code Finder hide settings",
        "Detected ports": "actually listening user TCP sockets working directory cwd refresh detached orange real process assigned saved multiple frontend backend Next Convex HMR inspector green dot",
        "Other ports in use": "section bottom dev server terminal cwd command stop SIGTERM PID confirmation dialog outside portfolio system processes filtered Tailscale ssh tunnels ControlCenter rapportd Continuity Mac apps Text Blaze MEGAsync OpenPort System usr Library Applications stop all never touches",
        "Live logs viewer": "magnifier document running modal stdout stderr stream search filter match count auto-scroll toggle copy clear buffer 1000 lines memory orphan detached pipes start inside",
        "Footer": "stop all multi-port siblings refresh command R folder git status change folder help settings sun moon light dark theme what's new blue dot changelog menu bar",
        "Settings": "launch startup auto menu bar quick launch network icon go links action buttons toggle browser copy QR logs terminal VS Code Finder what's new changelog",
        "go/ links": "http alias browser open matching app badge one-time setup 127.0.0.1 hosts launchd port 80 forwarder password prompt disable proxy stops hosts manual remove",
        "Menu bar": "quick launch network icon list apps running state start stop show OpenPort what's new changelog quit command Q",
        "Network URL": "copy LAN 192 paste device same Wi-Fi remote preview can't connect hostname 0.0.0.0 dev script package.json Next localhost",
        "Troubleshooting": "no apps found dev script package.json portfolio root won't start Node npm nvm alias default version live logs error port in use kill retry logs button missing started OpenPort detected port match cwd symlinks subfolders unidentified developer right click open"
    ]
}

private func helpText(_ string: String) -> some View {
    Text(.init(string))
        .font(.callout)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
}

private func helpRow(_ label: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
        Text(label)
            .font(.callout)
            .fontWeight(.semibold)
            .frame(width: 160, alignment: .leading)
        Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
