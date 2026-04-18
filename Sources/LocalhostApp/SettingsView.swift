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

                // Launch at startup
                Toggle(isOn: $launchAtStartup) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at startup")
                        Text("Start Localhost automatically when you log in.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtStartup) { _, enabled in
                    if enabled { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                }

                Divider()

                // Menu bar quick launch
                Toggle(isOn: $menuBarQuickLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu bar quick launch")
                        Text("Show your apps in the menu bar icon — start and stop without opening the window.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()

                // go/ links
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $goLinksEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("go/ links")
                            Text("Open any app by typing go/alias in your browser. Click an app name to set its alias.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: goLinksEnabled) { _, enabled in
                        model.setGoLinksEnabled(enabled)
                    }

                    if goLinksEnabled {
                        if goLinksSystemSetup {
                            Label("System routing active — go/alias works in any browser.", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("One-time system setup needed to route go/ in your browser (adds a /etc/hosts entry and a port redirect). Requires your password once.")
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
        .padding(24)
        .frame(width: 420, height: goLinksEnabled && !goLinksSystemSetup ? 360 : 300)
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
    static let launchdLabel = "com.serdarsalim.localhost3000.pf"
    static let launchdPath = "/Library/LaunchDaemons/\(launchdLabel).plist"
    static let pfAnchor = "com.localhost3000"

    static func install() async -> Bool {
        let plist = buildPlist()
        let tempPath = NSTemporaryDirectory() + "localhost3000.pf.plist"
        guard (try? plist.write(toFile: tempPath, atomically: true, encoding: .utf8)) != nil else { return false }

        let cmd = """
        grep -q '127.0.0.1 go' /etc/hosts || printf '\\n127.0.0.1 go\\n' >> /etc/hosts; \
        cp '\(tempPath)' '\(launchdPath)'; \
        launchctl load -w '\(launchdPath)' 2>/dev/null || true; \
        echo 'rdr pass on lo0 proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port 9080' | pfctl -a '\(pfAnchor)' -f - 2>/dev/null || true; \
        pfctl -e 2>/dev/null || true
        """
        let script = "do shell script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        return await runAppleScript(script)
    }

    static func uninstall() async -> Bool {
        let cmd = """
        sed -i '' '/127.0.0.1 go$/d' /etc/hosts; \
        launchctl unload '\(launchdPath)' 2>/dev/null || true; \
        rm -f '\(launchdPath)'; \
        pfctl -a '\(pfAnchor)' -F all 2>/dev/null || true
        """
        let script = "do shell script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        return await runAppleScript(script)
    }

    private static func buildPlist() -> String {
        let pfCmd = "echo 'rdr pass on lo0 proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port 9080' | /sbin/pfctl -a \(pfAnchor) -f - 2>/dev/null; /sbin/pfctl -e 2>/dev/null; true"
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchdLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>\(pfCmd)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
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
