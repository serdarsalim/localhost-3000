import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var apps: [DevApp] = []
    @Published var portfolioRoot: URL?
    @Published var isLoading = false

    private let processManager = ProcessManager()
    private let portStore = PortStore()
    private let defaults = UserDefaults.standard

    init() {
        if let path = defaults.string(forKey: "portfolioRoot") {
            portfolioRoot = URL(fileURLWithPath: path)
        }
        processManager.onTerminated = { [weak self] name in
            guard let self else { return }
            self.update(name) { app in
                app.isRunning = false
                app.portStatus = .crashed
            }
        }
    }

    func setPortfolioRoot(_ url: URL) {
        portfolioRoot = url
        defaults.set(url.path, forKey: "portfolioRoot")
        Task { await refresh() }
    }

    func refresh() async {
        guard let root = portfolioRoot else { return }
        isLoading = true
        defer { isLoading = false }

        let scanner = AppScanner(portfolioRoot: root)
        let appNames = scanner.scan()
        let ports = portStore.assign(to: appNames)
        let runningNames = Set(appNames.filter { processManager.isRunning(name: $0) })

        let gitStatuses: [String: GitStatus] = await withTaskGroup(of: (String, GitStatus).self) { group in
            for name in appNames {
                let appDir = root.appendingPathComponent(name)
                group.addTask { (name, await GitClient.status(at: appDir)) }
            }
            var results: [String: GitStatus] = [:]
            for await (name, git) in group { results[name] = git }
            return results
        }

        let portListening: [String: Bool] = await withTaskGroup(of: (String, Bool).self) { group in
            for name in appNames {
                let port = ports[name] ?? 3000
                group.addTask { (name, SystemClient.isPortListening(port)) }
            }
            var results: [String: Bool] = [:]
            for await (name, listening) in group { results[name] = listening }
            return results
        }

        apps = appNames.map { name in
            let weStartedIt = runningNames.contains(name)
            let listening = portListening[name] ?? false
            let status: PortStatus = switch (weStartedIt, listening) {
                case (true,  true):  .running
                case (true,  false): .crashed
                case (false, true):  .external
                case (false, false): .free
            }
            return DevApp(
                name: name,
                port: ports[name] ?? 3000,
                isRunning: weStartedIt,
                portStatus: status,
                gitStatus: gitStatuses[name] ?? .unknown
            )
        }
    }

    func start(app: DevApp) {
        guard let root = portfolioRoot else { return }
        processManager.start(name: app.name, port: app.port, in: root.appendingPathComponent(app.name))
        update(app.name) { $0.isRunning = true; $0.portStatus = .running }
    }

    func stop(app: DevApp) {
        processManager.stop(name: app.name)
        update(app.name) { $0.isRunning = false; $0.portStatus = .free }
    }

    func stopAll() {
        processManager.stopAll()
        for idx in apps.indices {
            apps[idx].isRunning = false
            apps[idx].portStatus = .free
        }
    }

    func updatePort(for app: DevApp, port: Int) {
        var ports = portStore.load()
        ports[app.name] = port
        portStore.save(ports)
        update(app.name) { $0.port = port }
    }

    func openTerminal(for app: DevApp) {
        guard let root = portfolioRoot else { return }
        SystemClient.openTerminal(at: root.appendingPathComponent(app.name))
    }

    func openEditor(for app: DevApp) {
        guard let root = portfolioRoot else { return }
        SystemClient.openVSCode(at: root.appendingPathComponent(app.name))
    }

    func openFinder(for app: DevApp) {
        guard let root = portfolioRoot else { return }
        SystemClient.openFinder(at: root.appendingPathComponent(app.name))
    }

    private func update(_ name: String, _ mutation: (inout DevApp) -> Void) {
        guard let idx = apps.firstIndex(where: { $0.name == name }) else { return }
        mutation(&apps[idx])
    }
}
