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
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    generalSection
                    goLinksSection
                    actionIconsSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 640)
        .onAppear {
            launchAtStartup = SMAppService.mainApp.status == .enabled
        }
    }

    private var generalSection: some View {
        settingsGroup(title: "General") {
            settingsRow(
                title: "Launch at startup",
                description: "Start Localhost automatically when you log in."
            ) {
                Toggle("", isOn: $launchAtStartup)
                    .labelsHidden()
                    .onChange(of: launchAtStartup) { _, enabled in
                        if enabled { try? SMAppService.mainApp.register() }
                        else { try? SMAppService.mainApp.unregister() }
                    }
            }
            Divider().padding(.leading, 12)
            settingsRow(
                title: "Menu bar quick launch",
                description: "Click the menu bar icon to start or stop any server without opening the app."
            ) {
                Toggle("", isOn: $menuBarQuickLaunch).labelsHidden()
            }
        }
    }

    private var goLinksSection: some View {
        settingsGroup(title: "Browser shortcuts") {
            settingsRow(
                title: "go/ links",
                description: "Type http://go/alias in your browser to open any app instantly. Click an app name in the main window to set its alias."
            ) {
                Toggle("", isOn: $goLinksEnabled)
                    .labelsHidden()
                    .onChange(of: goLinksEnabled) { _, enabled in
                        model.setGoLinksEnabled(enabled)
                    }
            }

            if goLinksEnabled {
                Divider().padding(.leading, 12)
                goLinksSetupRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private var goLinksSetupRow: some View {
        if goLinksSystemSetup {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("System routing active — go/alias works in any browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isSettingUp ? "Reinstalling…" : "Reinstall") {
                    Task { await runSetup() }
                }
                .font(.caption)
                .disabled(isSettingUp)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
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

    private var actionIconsSection: some View {
        settingsGroup(
            title: "Action icons",
            subtitle: "Choose which icons show in each app row."
        ) {
            ForEach(Array(ActionIcon.all.enumerated()), id: \.element.id) { idx, icon in
                if idx > 0 { Divider().padding(.leading, 44) }
                ActionIconToggleRow(icon: icon)
            }
        }
    }

    // MARK: - Layout helpers

    private func settingsGroup<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 2)

            VStack(spacing: 0) { content() }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func settingsRow<Trailing: View>(
        title: String,
        description: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
