import SwiftUI

struct AppRowView: View {
    let app: DevApp
    @ObservedObject var model: AppModel
    @State private var editingPort = false
    @State private var portDraft = ""
    @State private var copied = false

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
                HStack(spacing: 4) {
                    TextField("", text: $portDraft)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { savePort() }
                    Button {
                        savePort()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.green)
                    Button {
                        editingPort = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
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
        .frame(width: 100, alignment: .leading)
    }

    private func savePort() {
        if let port = Int(portDraft) {
            model.updatePort(for: app, port: port)
        }
        editingPort = false
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
