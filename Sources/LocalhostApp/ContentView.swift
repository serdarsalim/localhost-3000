import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
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
                DashboardView(model: model, schemeRaw: $schemeRaw)
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
    @State private var showHelp = false
    @State private var showSettings = false
    @AppStorage("goLinksEnabled") private var goLinksEnabled = false

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
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            if model.isLoading {
                ProgressView().scaleEffect(0.7)
            }
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
            footerIcon("questionmark.circle", help: "Help") { showHelp = true }
            footerIcon("gearshape", help: "Settings") { showSettings = true }

            Spacer()

            Text(appVersion)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

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

            ForEach(model.apps) { app in
                AppRowView(app: app, model: model)
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.inset)
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
