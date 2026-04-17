import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = AppModel()
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
        .frame(minWidth: 860, minHeight: 480)
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
            Text("Localhost 3000")
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

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
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
            Button("Refresh") { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: .command)
            Button("Change Folder") { pickFolder(model: model) }
            Button("Help") { showHelp = true }
            Spacer()
            Button {
                schemeRaw = schemeRaw == "dark" ? "light" : "dark"
            } label: {
                Image(systemName: schemeRaw == "dark" ? "moon.fill" : "sun.max.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(schemeRaw == "dark" ? "Switch to light mode" : "Switch to dark mode")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var appTable: some View {
        List(model.apps) { app in
            AppRowView(app: app, model: model)
                .listRowSeparator(.visible)
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
