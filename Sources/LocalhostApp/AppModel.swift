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

        // Run git checks, port checks, and external process scan in parallel
        async let gitTask = withTaskGroup(of: (String, GitStatus).self) { group in
            for name in appNames {
                let appDir = root.appendingPathComponent(name)
                group.addTask { (name, await GitClient.status(at: appDir)) }
            }
            var r: [String: GitStatus] = [:]
            for await (name, git) in group { r[name] = git }
            return r
        }

        async let portTask = withTaskGroup(of: (String, Bool).self) { group in
            for name in appNames {
                let port = ports[name] ?? 3000
                group.addTask { (name, SystemClient.isPortListening(port)) }
            }
            var r: [String: Bool] = [:]
            for await (name, listening) in group { r[name] = listening }
            return r
        }

        async let detectTask = Task.detached { SystemClient.detectRunningServers() }.value

        let (gitStatuses, portListening, detected) = await (gitTask, portTask, detectTask)

        // Build a lookup: project directory path -> DetectedServer
        let detectedByDir: [String: DetectedServer] = Dictionary(
            detected.map { ($0.directory, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        apps = appNames.map { name in
            let appDir = root.appendingPathComponent(name).path
            let assignedPort = ports[name] ?? 3000
            let weStartedIt = runningNames.contains(name)
            let assignedPortListening = portListening[name] ?? false
            let externalServer = detectedByDir[appDir]

            let status: PortStatus
            let detectedPort: Int?
            let externalPID: Int32?

            if weStartedIt && assignedPortListening {
                status = .running
                detectedPort = nil
                externalPID = nil
            } else if weStartedIt && !assignedPortListening {
                status = .crashed
                detectedPort = nil
                externalPID = nil
            } else if let server = externalServer {
                // A node process is running in this project's directory
                status = .detached
                detectedPort = server.port
                externalPID = server.pid
            } else if assignedPortListening {
                // Something else is on the assigned port but not this project
                status = .external
                detectedPort = nil
                externalPID = nil
            } else {
                status = .free
                detectedPort = nil
                externalPID = nil
            }

            return DevApp(
                name: name,
                port: assignedPort,
                isRunning: weStartedIt,
                portStatus: status,
                detectedPort: detectedPort,
                externalPID: externalPID,
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
        if app.isRunning {
            processManager.stop(name: app.name)
        } else if let pid = app.externalPID {
            kill(pid, SIGTERM)
        }
        update(app.name) { $0.isRunning = false; $0.portStatus = .free; $0.detectedPort = nil; $0.externalPID = nil }
    }

    func stopAll() {
        processManager.stopAll()
        for idx in apps.indices {
            if let pid = apps[idx].externalPID { kill(pid, SIGTERM) }
            apps[idx].isRunning = false
            apps[idx].portStatus = .free
            apps[idx].detectedPort = nil
            apps[idx].externalPID = nil
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
