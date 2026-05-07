import SwiftUI
import AppKit
import Combine
import ServiceManagement

@main
struct LocalhostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("OpenPort") {
            ContentView()
                .environmentObject(appDelegate.model)
                .environmentObject(appDelegate.terminalStore)
        }
        .windowResizability(.contentMinSize)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appDelegate.model)
                .environmentObject(appDelegate.terminalStore)
        }
        .windowResizability(.contentSize)

        Window("OpenPort — Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let terminalStore = TerminalSessionStore()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupMenuBarIcon()

        // Make the macOS title bar transparent so we can render our own header inside the
        // window. Traffic lights stay, but we get full control of left/right alignment.
        DispatchQueue.main.async {
            for window in NSApp.windows where window.identifier?.rawValue.hasPrefix("OpenPort") == true || window.title == "OpenPort" {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
            }
        }

        // Reap leftover processes from a previous OpenPort session that quit without cleanup.
        model.reapPortfolioOrphans()

        model.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous SIGTERM → 500ms → SIGKILL on every spawned PID. Without this, children
        // get reparented to launchd (PPID=1) and outlive every future OpenPort launch invisibly.
        model.nukeAllSync()
    }

    private func setupMenuBarIcon() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        let quickLaunch = UserDefaults.standard.bool(forKey: "menuBarQuickLaunch")

        // Remove icon entirely when quick launch is off
        guard quickLaunch else {
            statusItem = nil
            return
        }

        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem?.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Localhost")
        }

        let menu = NSMenu()

        if !model.apps.isEmpty {
            let goLinksEnabled = UserDefaults.standard.bool(forKey: "goLinksEnabled")
            for app in model.apps {
                let isActive = app.isRunning || app.portStatus == .detached
                let indicator = isActive ? "■" : "▶"
                let indicatorColor: NSColor = isActive ? .systemRed : .systemGreen
                let suffix = goLinksEnabled ? "  go/\(app.goAlias)" : "  :\(app.detectedPort ?? app.port)"

                let attributed = NSMutableAttributedString()
                attributed.append(NSAttributedString(
                    string: indicator,
                    attributes: [
                        .foregroundColor: indicatorColor,
                        .strokeColor: NSColor.black.withAlphaComponent(0.35),
                        .strokeWidth: -1.5
                    ]
                ))
                attributed.append(NSAttributedString(
                    string: "  \(app.name)\(suffix)",
                    attributes: [.foregroundColor: NSColor.labelColor]
                ))

                let item = NSMenuItem(title: "", action: #selector(toggleApp(_:)), keyEquivalent: "")
                item.attributedTitle = attributed
                item.target = self
                item.representedObject = app.name
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "Show OpenPort", action: #selector(showWindow), keyEquivalent: ""))

        let whatsNewItem = NSMenuItem(title: "What's new", action: #selector(showWhatsNew), keyEquivalent: "")
        whatsNewItem.target = self
        menu.addItem(whatsNewItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showWhatsNew() {
        showWindow()
        NotificationCenter.default.post(name: .openPortShowWhatsNew, object: nil)
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

extension Notification.Name {
    static let openPortShowWhatsNew = Notification.Name("OpenPortShowWhatsNew")
}
