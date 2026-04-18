import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("menuBarQuickLaunch") private var menuBarQuickLaunch = false
    @AppStorage("goLinksEnabled") private var goLinksEnabled = false
    @State private var launchAtStartup = false
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
                        Text("Show your apps in the menu bar icon — start and stop without opening the window.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $goLinksEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("go links")
                        Text("Open any app by typing alias.localhost:9080 in your browser. Click an app name to set its alias. No setup required.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: goLinksEnabled) { _, enabled in
                    model.setGoLinksEnabled(enabled)
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
        .frame(width: 420, height: 280)
        .onAppear {
            launchAtStartup = SMAppService.mainApp.status == .enabled
        }
    }
}
