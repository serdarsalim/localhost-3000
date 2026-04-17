import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("menuBarQuickLaunch") private var menuBarQuickLaunch = false
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtStartup) { _, enabled in
                    if enabled {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

                Divider()

                Toggle(isOn: $menuBarQuickLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu bar quick launch")
                        Text("Show your apps in the menu bar icon — start and stop without opening the window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        .frame(width: 380, height: 240)
        .onAppear {
            launchAtStartup = SMAppService.mainApp.status == .enabled
        }
    }
}
