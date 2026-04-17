import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("What is this?") {
                        text("Localhost 3000 scans a folder of web projects and lets you start, stop, and open their dev servers without touching the terminal. Any project with a \"dev\" script in its package.json shows up here.")
                    }

                    section("First time setup") {
                        text("Click **Change Folder** in the footer and pick the folder that contains all your projects. If your projects live at ~/my-portfolio/cadencia, ~/my-portfolio/yummii, etc. — pick ~/my-portfolio. The app remembers it.")
                    }

                    section("The dashboard") {
                        row("Grey / green dot", "Running status. Grey = stopped, green = running.")
                        row("Port number", "Click to type a new port. Scroll with the mouse wheel to nudge ±1.")
                        row("Git status", "Clean means no uncommitted changes. Orange means you have unsaved git work.")
                        row("Start / Stop", "Starts or stops the dev server for that project.")
                    }

                    section("Action icons") {
                        row("🌐  Globe", "Opens the project in your browser. Only shows when running.")
                        row("📋  Clipboard", "Copies the network URL (192.168.x.x:PORT) so you can open the project on your phone or another device on the same Wi-Fi.")
                        row(">_  Terminal", "Opens the project folder in Terminal.")
                        row("</>  Code", "Opens the project in VS Code.")
                        row("📁  Folder", "Opens the project in Finder.")
                    }

                    section("Footer buttons") {
                        row("Stop All", "Stops every running dev server at once.")
                        row("Refresh", "Re-scans your folder and updates git status.")
                        row("Change Folder", "Pick a different portfolio root folder.")
                        row("Appearance icon", "Cycles through light → dark → system appearance.")
                    }

                    section("Network URL") {
                        text("The clipboard icon copies a URL like http://192.168.1.42:3001. Paste it into any device on the same Wi-Fi to preview your project remotely.")
                        text("If the device can't connect, add --hostname 0.0.0.0 to your \"dev\" script in package.json.")
                    }

                    section("Troubleshooting") {
                        row("No apps found", "Make sure your projects have a \"dev\" script in package.json and you picked the right root folder.")
                        row("Project won't start", "Check that Node and npm are installed. If you use nvm, set a default version: nvm alias default <version>.")
                        row("Port already in use", "Change the port to a free one, or run: lsof -ti :3001 | xargs kill")
                        row("Unidentified developer", "Right-click the app → Open → Open. macOS only asks once.")
                    }
                }
                .padding(28)
            }
        }
        .frame(width: 560, height: 620)
    }

    private var header: some View {
        HStack {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("Localhost 3000 — Help")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            content()
        }
    }

    private func text(_ string: String) -> some View {
        Text(LocalizedStringKey(string))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ label: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.callout)
                .fontWeight(.medium)
                .frame(width: 160, alignment: .leading)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
