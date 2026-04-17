import SwiftUI
import CoreImage

struct AppRowView: View {
    let app: DevApp
    @ObservedObject var model: AppModel
    @State private var editingPort = false
    @State private var portDraft = ""
    @State private var portConflict = false
    @State private var copied = false
    @State private var showQR = false

    private var takenPorts: Set<Int> {
        Set(model.apps.filter { $0.name != app.name }.map { $0.port })
    }

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
            .fill(dotColor)
            .frame(width: 9, height: 9)
            .help(dotTooltip)
    }

    private var dotColor: Color {
        switch app.portStatus {
        case .running:  .green
        case .detached: .green
        case .crashed:  .red
        case .external: .orange
        case .free:     Color.secondary.opacity(0.25)
        }
    }

    private var dotTooltip: String {
        switch app.portStatus {
        case .running:  "Running on :\(app.port)"
        case .detached: "Running on :\(app.detectedPort ?? app.port) (started outside this app)"
        case .crashed:  "Crashed — was running on :\(app.port) but stopped responding"
        case .external: "Port \(app.port) is in use by an unrelated process"
        case .free:     "Stopped"
        }
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
                    TextField("", text: $portDraft)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(portConflict ? .red : .primary)
                        .onSubmit { savePort() }
                        .scrollWheelHandler { delta in nudgePort(by: delta > 0 ? 1 : -1) }
                        .onChange(of: portDraft) { _, _ in portConflict = false }
                    Button { savePort() } label: {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(portConflict ? .red : .green)
                    Button { editingPort = false } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "\(app.detectedPort ?? app.port)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        guard !app.isRunning && app.portStatus != .detached else { return }
                        portDraft = "\(app.port)"
                        editingPort = true
                    }
                    .help(app.isRunning || app.portStatus == .detached ? "Stop the server to change its port" : "Click to edit port")
            }
        }
        .frame(width: 100, alignment: .leading)
    }

    private func savePort() {
        guard let port = Int(portDraft) else { editingPort = false; return }
        if takenPorts.contains(port) {
            portConflict = true
            return
        }
        model.updatePort(for: app, port: port)
        editingPort = false
    }

    private func nudgePort(by delta: Int) {
        var next = (Int(portDraft) ?? app.port) + delta
        while takenPorts.contains(next) { next += delta }
        portDraft = "\(next)"
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

    private var activePort: Int { app.detectedPort ?? app.port }
    private var isActive: Bool { app.isRunning || app.portStatus == .detached }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if isActive {
                Button {
                    SystemClient.openBrowser(port: activePort)
                } label: {
                    Image(systemName: "globe")
                }
                .help("Open in browser")
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    SystemClient.copyNetworkURL(port: activePort)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help(copied ? "Copied!" : "Copy network URL (for other devices)")
                .buttonStyle(.plain)
                .foregroundStyle(copied ? .green : .secondary)
                .animation(.easeInOut(duration: 0.2), value: copied)

                Button { showQR = true } label: {
                    Image(systemName: "qrcode")
                }
                .help("Show QR code to open on another device")
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $showQR, arrowEdge: .bottom) {
                    QRPopover(port: activePort)
                }
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

    @ViewBuilder
    private var startStopButton: some View {
        if app.isRunning || app.portStatus == .crashed || app.portStatus == .detached {
            Button("Stop") { model.stop(app: app) }
                .foregroundStyle(.red)
                .frame(width: 44)
        } else {
            Button("Start") { model.start(app: app) }
                .foregroundStyle(app.portStatus == .external ? Color.secondary : Color.green)
                .disabled(app.portStatus == .external)
                .help(app.portStatus == .external ? "Port \(app.port) is in use — change the port first" : "")
                .frame(width: 44)
        }
    }
}

struct QRPopover: View {
    let port: Int

    private var networkURL: String {
        "http://\(SystemClient.lanIPAddress()):\(port)"
    }

    private var qrImage: Image? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(networkURL.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
        return Image(nsImage: nsImage)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let image = qrImage {
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
            } else {
                Text("QR unavailable").foregroundStyle(.secondary)
            }
            Text(networkURL)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 212)
    }
}
