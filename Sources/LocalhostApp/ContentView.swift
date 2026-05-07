import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var terminalStore: TerminalSessionStore
    @AppStorage("colorScheme") private var schemeRaw: String = "system"

    private var preferredScheme: ColorScheme? {
        switch schemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        Group {
            if model.portfolioRoot == nil {
                WelcomeView(model: model)
            } else {
                VStack(spacing: 0) {
                    TabBarView(store: terminalStore)
                    ZStack {
                        DashboardView(model: model, schemeRaw: $schemeRaw)
                            .opacity(terminalStore.selectedTab == .dashboard ? 1 : 0)
                            .allowsHitTesting(terminalStore.selectedTab == .dashboard)

                        ForEach(terminalStore.sessions) { session in
                            TerminalTabView(session: session)
                                .opacity(terminalStore.selectedTab == .session(session.id) ? 1 : 0)
                                .allowsHitTesting(terminalStore.selectedTab == .session(session.id))
                        }
                    }
                }
            }
        }
        .frame(minWidth: 880, minHeight: 480)
        .preferredColorScheme(preferredScheme)
    }
}

struct WelcomeView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("OpenPort")
                .font(.title)
                .fontWeight(.semibold)
            Text("Pick your portfolio root folder to get started.")
                .foregroundStyle(.secondary)
            Button("Choose Folder") {
                pickFolder(model: model)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @Binding var schemeRaw: String
    @Environment(\.openWindow) private var openWindow
    @State private var showWhatsNew = false
    @State private var searchText = ""
    @AppStorage("goLinksEnabled") private var goLinksEnabled = false
    @AppStorage("lastSeenChangelogVersion") private var lastSeenChangelogVersion = ""

    private var hasUnseenChangelog: Bool {
        lastSeenChangelogVersion != Changelog.latestVersion
    }

    private var filteredApps: [DevApp] {
        guard !searchText.isEmpty else { return model.apps }
        return model.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if model.apps.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No apps found",
                    systemImage: "folder.badge.questionmark",
                    description: Text("No directories with a \(Text("\"dev\"").monospaced()) script found.")
                )
            } else {
                appTable
            }
            Divider()
            footer
        }
        .task { await model.refresh() }
        .sheet(isPresented: $showWhatsNew, onDismiss: {
            lastSeenChangelogVersion = Changelog.latestVersion
        }) {
            WhatsNewSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPortShowWhatsNew)) { _ in
            showWhatsNew = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Spacer()
            ProgressView()
                .scaleEffect(0.55)
                .opacity(model.isLoading ? 1 : 0)
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Stop All") { model.stopAll() }
                .foregroundStyle(.red)

            Divider().frame(height: 14).padding(.horizontal, 4)

            footerIcon("arrow.clockwise", help: "Refresh (⌘R)") { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: .command)
            footerIcon("folder.badge.gear", help: "Change folder") { pickFolder(model: model) }
            footerIcon("questionmark.circle", help: "Help") { openWindow(id: "help") }
            footerIcon("gearshape", help: "Settings") { openWindow(id: "settings") }

            Spacer()

            if hasUnseenChangelog {
                Button {
                    showWhatsNew = true
                } label: {
                    HStack(spacing: 4) {
                        Text("What's new")
                            .font(.system(size: 11))
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("New since you last looked")
            }

            footerIcon(schemeRaw == "dark" ? "moon.fill" : "sun.max.fill",
                       help: schemeRaw == "dark" ? "Switch to light mode" : "Switch to dark mode") {
                schemeRaw = schemeRaw == "dark" ? "light" : "dark"
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func footerIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private var appTable: some View {
        List {
            HStack(spacing: 14) {
                Color.clear.frame(width: 28)  // play/stop button
                Text("App")
                    .frame(minWidth: goLinksEnabled ? 200 : 280, alignment: .leading)
                if goLinksEnabled {
                    Text("go/ link")
                        .frame(width: 210, alignment: .leading)
                }
                Text("Port")
                    .frame(width: 90, alignment: .leading)
                Text("Git")
                    .frame(width: 70, alignment: .leading)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden, edges: .top)
            .listRowSeparator(.visible, edges: .bottom)
            .listRowBackground(Color.clear)
            .allowsHitTesting(false)

            ForEach(filteredApps) { app in
                AppRowView(app: app, model: model)
                    .listRowSeparator(.visible)
            }

            if !model.orphans.isEmpty {
                otherPortsHeader
                ForEach(model.orphans) { orphan in
                    OrphanRowView(orphan: orphan, model: model)
                        .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(.inset)
    }

    private var otherPortsHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .font(.caption)
            Text("Other ports in use")
            Text("(\(model.orphans.count))")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .allowsHitTesting(false)
    }
}

struct OrphanRowView: View {
    let orphan: OrphanPort
    @ObservedObject var model: AppModel
    @State private var isHovered = false
    @State private var showConfirm = false

    private var dirLabel: String {
        guard !orphan.directory.isEmpty else { return "—" }
        return (orphan.directory as NSString).lastPathComponent
    }

    private var isOutsidePortfolio: Bool {
        guard let root = model.portfolioRoot?.path else { return true }
        return !orphan.directory.hasPrefix(root)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                if isOutsidePortfolio { showConfirm = true } else { model.stopOrphan(orphan) }
            } label: {
                Image(systemName: "stop.fill").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.8))
            .help("Stop process \(orphan.pid)")
            .frame(width: 28)
            .confirmationDialog(
                "Stop \(orphan.command) on port \(orphan.port)?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Stop process \(orphan.pid)", role: .destructive) {
                    model.stopOrphan(orphan)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(orphan.directory.isEmpty ? "(no working directory)" : orphan.directory)
            }

            Text(dirLabel)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 200, alignment: .leading)

            Text(verbatim: "\(orphan.port)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(orphan.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            Button {
                SystemClient.openBrowser(port: orphan.port)
            } label: {
                Image(systemName: "globe")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .help("Open in browser")

            Button {
                SystemClient.copyNetworkURL(port: orphan.port)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Copy network URL")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .help(orphan.directory.isEmpty ? "Process \(orphan.pid)" : orphan.directory)
    }
}

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("What's new")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Changelog.entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(entry.version)
                                    .font(.system(.headline, design: .monospaced))
                                Text(entry.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entry.items, id: \.self) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(.tertiary)
                                        Text(item)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 540, height: 520)
    }
}

@MainActor
private func pickFolder(model: AppModel) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Select"
    panel.message = "Select your portfolio root folder"
    if panel.runModal() == .OK, let url = panel.url {
        model.setPortfolioRoot(url)
    }
}
