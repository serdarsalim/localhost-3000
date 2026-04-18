import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("menuBarQuickLaunch") private var menuBarQuickLaunch = false
    @AppStorage("goLinksEnabled") private var goLinksEnabled = false
    @AppStorage("goLinksSystemSetup") private var goLinksSystemSetup = false
    @State private var launchAtStartup = false
    @State private var isSettingUp = false
    @State private var setupError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 16) {

                Toggle(isOn: $launchAtStartup) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at startup")
                        Text("Start Localhost automatically when you log in.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .onChange(of: launchAtStartup) { _, enabled in
                    if enabled { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                }

                Divider()

                Toggle(isOn: $menuBarQuickLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu bar quick launch")
                        Text("Click the menu bar icon and your apps appear right there — start or stop any server without opening the app at all.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $goLinksEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("go/ links")
                            Text("Type http://go/alias in your browser to open any app instantly. Click an app name in the main window to set its alias.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
            }
            .padding(.top, 20)
        }
        .padding(28)
        .frame(width: 460, height: goLinksEnabled && !goLinksSystemSetup ? 420 : 360)
        .onAppear {
            launchAtStartup = SMAppService.mainApp.status == .enabled
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
