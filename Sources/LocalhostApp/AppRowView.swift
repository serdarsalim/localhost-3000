import SwiftUI

struct AppRowView: View {
    let app: DevApp
    @ObservedObject var model: AppModel
    @State private var editingPort = false
    @State private var portDraft = ""
    @State private var copied = false
    @FocusState private var portFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            statusDot
            appName
            portBadge
            gitBadge
            Spacer()
            actionButtons
            startStopButton
        }
        .padding(.vertical, 5)
    }

    private var statusDot: some View {
        Circle()
            .fill(app.isRunning ? Color.green : Color.secondary.opacity(0.25))
            .frame(width: 9, height: 9)
    }

    private var appName: some View {
        Text(app.name)
            .fontWeight(.medium)
            .frame(minWidth: 240, alignment: .leading)
    }

    private var portBadge: some View {
        Group {
            if editingPort {
                HStack(spacing: 2) {
                    TextField("Port", text: $portDraft)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($portFocused)
                        .onSubmit { commitPort() }
                        .onChange(of: portFocused) { _, focused in
                            if !focused { commitPort() }
                        }
                        .scrollWheelHandler { delta in nudgePort(by: delta > 0 ? 1 : -1) }
                    VStack(spacing: 0) {
                        Button { nudgePort(by: 1) } label: {
                            Image(systemName: "chevron.up").font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        Button { nudgePort(by: -1) } label: {
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "\(app.port)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        portDraft = "\(app.port)"
                        editingPort = true
                    }
                    .help("Click to edit port")
            }
        }
        .frame(width: 80, alignment: .leading)
    }

    private func commitPort() {
        if let port = Int(portDraft) { model.updatePort(for: app, port: port) }
        editingPort = false
    }

    private func nudgePort(by delta: Int) {
        let current = Int(portDraft) ?? app.port
        portDraft = "\(current + delta)"
    }

    private var gitBadge: some View {
        Group {
            if app.gitStatus.isRepo {
                if app.gitStatus.uncommittedCount > 0 {
                    Label("\(app.gitStatus.uncommittedCount) uncommitted", systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("Clean", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                Text("—").foregroundStyle(.tertiary).font(.caption)
            }
        }
        .frame(width: 110, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if app.isRunning {
                Button {
                    SystemClient.openBrowser(port: app.port)
                } label: {
                    Image(systemName: "globe")
                }
                .help("Open in browser")
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    SystemClient.copyNetworkURL(port: app.port)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help(copied ? "Copied!" : "Copy network URL (for other devices)")
                .buttonStyle(.plain)
                .foregroundStyle(copied ? .green : .secondary)
                .animation(.easeInOut(duration: 0.2), value: copied)
            }

            Button { model.openTerminal(for: app) } label: {
                Image(systemName: "terminal")
            }
            .help("Open in Terminal")
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button { model.openEditor(for: app) } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("Open in VS Code")
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button { model.openFinder(for: app) } label: {
                Image(systemName: "folder")
            }
            .help("Open in Finder")
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var startStopButton: some View {
        Button(app.isRunning ? "Stop" : "Start") {
            if app.isRunning { model.stop(app: app) } else { model.start(app: app) }
        }
        .foregroundStyle(app.isRunning ? .red : .green)
        .frame(width: 44)
    }
}
