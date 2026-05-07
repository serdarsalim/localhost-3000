import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("menuBarQuickLaunch") private var menuBarQuickLaunch = false
    @AppStorage("goLinksEnabled") private var goLinksEnabled = false
    @AppStorage("goLinksSystemSetup") private var goLinksSystemSetup = false
    @AppStorage("showActionBrowser") private var showActionBrowser = true
    @AppStorage("showActionCopy") private var showActionCopy = true
    @AppStorage("showActionQR") private var showActionQR = true
    @AppStorage("showActionTerminal") private var showActionTerminal = true
    @AppStorage("showActionEditor") private var showActionEditor = true
    @AppStorage("showActionFinder") private var showActionFinder = true
    @AppStorage("showActionLogs") private var showActionLogs = true
    @AppStorage("useExternalTerminal") private var useExternalTerminal = false
    @State private var launchAtStartup = false
    @State private var isSettingUp = false
    @State private var setupError: String?
    @State private var showWhatsNew = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 16) {

                settingRow(
                    title: "Launch at startup",
                    subtitle: "Start Localhost automatically when you log in.",
                    binding: $launchAtStartup
                )
                .onChange(of: launchAtStartup) { _, enabled in
                    if enabled { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                }

                Divider()

                settingRow(
                    title: "Menu bar quick launch",
                    subtitle: "Access your apps from the menu bar.",
                    binding: $menuBarQuickLaunch
                )

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    settingRow(
                        title: "go/ links",
                        subtitle: "Type http://go/alias in your browser to open any app instantly. Click an app name in the main window to set its alias.",
                        binding: $goLinksEnabled
                    )
                    .onChange(of: goLinksEnabled) { _, enabled in
                        model.setGoLinksEnabled(enabled)
                    }

                    if goLinksEnabled {
                        if goLinksSystemSetup {
                            HStack {
                                Label("System routing active — go/alias works in any browser.", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                                Button(isSettingUp ? "Reinstalling…" : "Reinstall") {
                                    Task { await runSetup() }
                                }
                                .font(.caption)
                                .disabled(isSettingUp)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("One-time setup required. Adds a local hostname and installs a port forwarder so go/alias works in any browser. Requires your password once.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Button(isSettingUp ? "Setting up…" : "Setup System") {
                                        Task { await runSetup() }
                                    }
                                    .disabled(isSettingUp)
                                    if let err = setupError {
                                        Text(err).font(.caption).foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                settingRow(
                    title: "Use external Terminal.app",
                    subtitle: "Open the terminal button in macOS Terminal.app instead of a tab inside OpenPort.",
                    binding: $useExternalTerminal
                )

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Action buttons")
                        .fontWeight(.medium)
                    Text("Hide buttons you don't use to keep rows compact.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    actionToggle("Open in browser", systemImage: "globe", binding: $showActionBrowser)
                    actionToggle("Copy network URL", systemImage: "doc.on.doc", binding: $showActionCopy)
                    actionToggle("QR code", systemImage: "qrcode", binding: $showActionQR)
                    actionToggle("View live logs", systemImage: "doc.text.magnifyingglass", binding: $showActionLogs)
                    actionToggle("Open in Terminal", systemImage: "terminal", binding: $showActionTerminal)
                    actionToggle("Open in VS Code", systemImage: "chevron.left.forwardslash.chevron.right", binding: $showActionEditor)
                    actionToggle("Open in Finder", systemImage: "folder", binding: $showActionFinder)
                }
            }

            Spacer()

            HStack {
                Button {
                    showWhatsNew = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("What's new")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return)
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showWhatsNew) { WhatsNewSheet() }
        .padding(28)
        .frame(width: 460, height: goLinksEnabled && !goLinksSystemSetup ? 660 : 600)
        .onAppear {
            launchAtStartup = SMAppService.mainApp.status == .enabled
        }
    }

    private func settingRow(title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    private func actionToggle(_ label: String, systemImage: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label)
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private func runSetup() async {
        isSettingUp = true
        setupError = nil
        let success = await GoLinksSetup.install()
        isSettingUp = false
        if success {
            goLinksSystemSetup = true
        } else {
            setupError = "Setup failed or was cancelled."
        }
    }
}

enum GoLinksSetup {
    static let label    = "com.serdarsalim.localhost3000.port80"
    static let plistDst = "/Library/LaunchDaemons/\(label).plist"

    // Python TCP forwarder: listens on :80, forwards every connection to :9080
    static let pythonScript = """
import socket,threading
def handle(c):
    s=socket.socket()
    s.connect(('127.0.0.1',9080))
    def fwd(a,b):
        try:
            while True:
                d=a.recv(4096)
                if not d:break
                b.sendall(d)
        except:pass
        finally:a.close();b.close()
    threading.Thread(target=fwd,args=(c,s),daemon=True).start()
    threading.Thread(target=fwd,args=(s,c),daemon=True).start()
s=socket.socket()
s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
s.bind(('127.0.0.1',80))
s.listen(100)
while True:handle(s.accept()[0])
"""

    static func install() async -> Bool {
        let plist = buildPlist()
        let tempPath = NSTemporaryDirectory() + "localhost3000.port80.plist"
        guard (try? plist.write(toFile: tempPath, atomically: true, encoding: .utf8)) != nil else { return false }

        let cmd = [
            "grep -q '127.0.0.1 go' /etc/hosts || printf '\\n127.0.0.1 go\\n' >> /etc/hosts",
            "cp '\(tempPath)' '\(plistDst)'",
            "launchctl load -w '\(plistDst)'"
        ].joined(separator: "; ")

        return await runAppleScript("do shell script \"\(escaped(cmd))\" with administrator privileges")
    }

    static func uninstall() async -> Bool {
        let cmd = [
            "launchctl unload '\(plistDst)' 2>/dev/null || true",
            "rm -f '\(plistDst)'",
            "sed -i '' '/127\\.0\\.0\\.1 go$/d' /etc/hosts"
        ].joined(separator: "; ")

        return await runAppleScript("do shell script \"\(escaped(cmd))\" with administrator privileges")
    }

    private static func buildPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/python3</string>
                <string>-c</string>
                <string>\(pythonScript)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/localhost3000-port80.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/localhost3000-port80.log</string>
        </dict>
        </plist>
        """
    }

    private static func escaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ script: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }
            try? p.run()
        }
    }
}
