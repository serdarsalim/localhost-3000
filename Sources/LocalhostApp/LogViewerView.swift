import SwiftUI
import AppKit

/// Descriptor for every action icon in the app row. Used by both the row view
/// and the settings toggle list so they stay in sync.
struct ActionIcon: Identifiable {
    let id: String           // AppStorage key suffix
    let symbol: String
    let label: String
    let description: String

    static let all: [ActionIcon] = [
        .init(id: "browser",  symbol: "globe",                                 label: "Open in browser",  description: "Opens the running server in your default browser."),
        .init(id: "copyURL",  symbol: "doc.on.doc",                            label: "Copy network URL", description: "Copies the LAN URL so you can open the app on phones or other devices."),
        .init(id: "qr",       symbol: "qrcode",                                label: "QR code",          description: "Shows a QR code that opens the app on another device."),
        .init(id: "logs",     symbol: "text.alignleft",                        label: "Logs",             description: "Live stdout and stderr from the running server."),
        .init(id: "terminal", symbol: "terminal",                              label: "Open in Terminal", description: "Opens the project folder in Terminal."),
        .init(id: "editor",   symbol: "chevron.left.forwardslash.chevron.right", label: "Open in VS Code",  description: "Opens the project in VS Code."),
        .init(id: "finder",   symbol: "folder",                                label: "Open in Finder",   description: "Reveals the project folder in Finder.")
    ]

    var storageKey: String { "action.\(id).visible" }
}

struct ActionIconToggleRow: View {
    let icon: ActionIcon
    @State private var isOn: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon.symbol)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(icon.label)
                Text(icon.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            if UserDefaults.standard.object(forKey: icon.storageKey) == nil {
                isOn = true
            } else {
                isOn = UserDefaults.standard.bool(forKey: icon.storageKey)
            }
        }
        .onChange(of: isOn) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: icon.storageKey)
        }
    }
}

struct LogViewerView: View {
    @ObservedObject var buffer: LogBuffer
    let appName: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appName).font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(buffer.joined, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy all", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(copied ? .green : .secondary)

                Button { buffer.clear() } label: {
                    Label("Clear", systemImage: "trash").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if buffer.lines.isEmpty {
                            Text("No output yet. Start the server to see logs.")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(8)
                        } else {
                            ForEach(Array(buffer.lines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(idx)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .onChange(of: buffer.revision) { _, _ in
                    withAnimation(.linear(duration: 0.05)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .frame(width: 640, height: 460)
    }
}
