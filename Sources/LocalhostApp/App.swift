import SwiftUI
import AppKit
import Combine
import ServiceManagement

@main
struct LocalhostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Localhost 3000") {
            ContentView()
                .environmentObject(appDelegate.model)
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupMenuBarIcon()

        cancellable = model.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Localhost")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let quickLaunch = UserDefaults.standard.bool(forKey: "menuBarQuickLaunch")

        if quickLaunch && !model.apps.isEmpty {
            for app in model.apps {
                let indicator = app.isRunning ? "⏹" : "▶"
                let item = NSMenuItem(
                    title: "\(indicator)  \(app.name)  :\(app.port)",
                    action: #selector(toggleApp(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = app.name
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "Show Localhost", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func toggleApp(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let app = model.apps.first(where: { $0.name == name }) else { return }
        if app.isRunning { model.stop(app: app) } else { model.start(app: app) }
        rebuildMenu()
    }

    @objc private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
