import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var apps: [DevApp] = []
    @Published var orphans: [OrphanPort] = []
    @Published var portfolioRoot: URL?
    @Published var isLoading = false

    private let processManager = ProcessManager()
    private let portStore = PortStore()
    private let goLinkStore = GoLinkStore()
    private let proxyServer = ProxyServer()
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
                app.backendRunning = false
                app.crashLog = self.processManager.crashLog(for: name)
            }
        }
        if defaults.bool(forKey: "goLinksEnabled") {
            proxyServer.start()
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
        let scanned = scanner.scanWithPorts()
        let appNames = scanned.map(\.name)
        let scriptPorts = Dictionary(uniqueKeysWithValues: scanned.compactMap { item -> (String, Int)? in
            guard let p = item.scriptPort else { return nil }
            return (item.name, p)
        })
        let devScripts = Dictionary(uniqueKeysWithValues: scanned.compactMap { item -> (String, String)? in
            guard let s = item.devScript else { return nil }
            return (item.name, s)
        })
        let devScriptNames = Dictionary(uniqueKeysWithValues: scanned.compactMap { item -> (String, String)? in
            guard let n = item.devScriptName else { return nil }
            return (item.name, n)
        })
        let backendScriptNames = Dictionary(uniqueKeysWithValues: scanned.compactMap { item -> (String, String)? in
            guard let n = item.backendScriptName else { return nil }
            return (item.name, n)
        })
        let ports = portStore.assign(to: appNames, scriptPorts: scriptPorts)
        let goAliases = goLinkStore.load()
        let runningNames = Set(appNames.filter { processManager.isRunning(name: $0) })

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

        // Group all detected listeners by their cwd. One cwd may have many ports.
        var detectedByDir: [String: [DetectedServer]] = [:]
        for entry in detected {
            detectedByDir[entry.directory, default: []].append(entry)
        }

        let appDirSet = Set(appNames.map { root.appendingPathComponent($0).path })

        apps = appNames.map { name in
            let appDir = root.appendingPathComponent(name).path
            let assignedPort = ports[name] ?? 3000
            let weStartedIt = runningNames.contains(name)
            let assignedPortListening = portListening[name] ?? false
            let listenersForApp = detectedByDir[appDir] ?? []
            let goAlias = goAliases[name] ?? GoLinkStore.defaultAlias(for: name)

            // Pick a primary listener: prefer the one matching the assigned port,
            // otherwise the lowest-numbered port.
            let primary: DetectedServer? = listenersForApp.first(where: { $0.port == assignedPort })
                ?? listenersForApp.min(by: { $0.port < $1.port })

            let extras: [DetectedPort] = listenersForApp
                .filter { $0.port != primary?.port || $0.pid != primary?.pid }
                .map { DetectedPort(pid: $0.pid, port: $0.port, command: $0.command) }
                .sorted { $0.port < $1.port }

            let status: PortStatus
            let detectedPort: Int?
            let externalPID: Int32?

            if weStartedIt && assignedPortListening {
                status = .running; detectedPort = nil; externalPID = nil
            } else if weStartedIt && !assignedPortListening {
                status = .crashed; detectedPort = nil; externalPID = nil
            } else if let server = primary {
                status = .detached; detectedPort = server.port; externalPID = server.pid
            } else if assignedPortListening {
                status = .external; detectedPort = nil; externalPID = nil
            } else {
                status = .free; detectedPort = nil; externalPID = nil
            }

            return DevApp(
                name: name,
                port: assignedPort,
                isRunning: weStartedIt,
                portStatus: status,
                detectedPort: detectedPort,
                externalPID: externalPID,
                goAlias: goAlias,
                gitStatus: gitStatuses[name] ?? .unknown,
                devScript: devScripts[name],
                devScriptName: devScriptNames[name],
                backendScriptName: backendScriptNames[name],
                backendRunning: processManager.isBackendRunning(name: name),
                extraPorts: extras
            )
        }

        // Anything left over — listeners whose cwd isn't a known app folder.
        // System daemons, installed Mac apps, and OpenPort itself are filtered
        // out: killing those breaks Continuity, Tailscale, ssh tunnels, etc.
        orphans = detected
            .filter { !appDirSet.contains($0.directory) }
            .filter { !Self.isSystemOrInstalledApp($0) }
            .map { OrphanPort(pid: $0.pid, port: $0.port, directory: $0.directory, command: $0.command) }
            .sorted { $0.port < $1.port }

        refreshProxyRoutes()
    }

    /// Hide listeners that aren't user dev servers — system daemons, Mac apps,
    /// ssh tunnels, OpenPort itself.
    private static func isSystemOrInstalledApp(_ entry: DetectedServer) -> Bool {
        let cmd = entry.command
        let dir = entry.directory

        let blockedCommandPrefixes = [
            "/System/", "/usr/", "/Library/", "/Applications/",
            "/sbin/", "/bin/"
        ]
        if blockedCommandPrefixes.contains(where: { cmd.hasPrefix($0) }) { return true }

        if cmd.contains("LocalhostApp") || cmd.contains("OpenPort.app") { return true }

        if dir.isEmpty || dir == "/" { return true }

        let blockedDirPrefixes = [
            "/System/", "/Library/", "/private/var/", "/Applications/"
        ]
        if blockedDirPrefixes.contains(where: { dir.hasPrefix($0) }) { return true }

        return false
    }

    /// Kill an orphan listener by PID. Scoped narrowly — does NOT participate
    /// in stopAll(), since orphans may be unrelated apps the user cares about.
    func stopOrphan(_ orphan: OrphanPort) {
        kill(orphan.pid, SIGTERM)
        orphans.removeAll { $0.id == orphan.id }
    }

    func liveLog(for app: DevApp) -> String? {
        processManager.liveLog(for: app.name)
    }

    func clearLog(for app: DevApp) {
        processManager.clearLog(for: app.name)
    }

    func start(app: DevApp) {
        guard let root = portfolioRoot else { return }
        processManager.start(
            name: app.name,
            port: app.port,
            in: root.appendingPathComponent(app.name),
            devScript: app.devScript,
            devScriptName: app.devScriptName,
            backendScriptName: app.backendScriptName
        )
        update(app.name) {
            $0.isRunning = true
            $0.portStatus = .running
            $0.backendRunning = app.backendScriptName != nil
        }
        refreshProxyRoutes()
    }

    func stop(app: DevApp) {
        if app.isRunning {
            processManager.stop(name: app.name)
        } else if let pid = app.externalPID {
            kill(pid, SIGTERM)
        }
        let port = app.detectedPort ?? app.port
        let extraPids = app.extraPorts.map(\.pid)
        update(app.name) { $0.isRunning = false; $0.portStatus = .free; $0.detectedPort = nil; $0.externalPID = nil; $0.backendRunning = false; $0.crashLog = nil; $0.extraPorts = [] }
        refreshProxyRoutes()
        Task.detached {
            for pid in extraPids { kill(pid, SIGTERM) }
            SystemClient.killPort(port)
        }
    }

    func stopAll() {
        processManager.stopAll()

        // Stays scoped to listed apps — orphans are deliberately untouched.
        let portsToKill = apps.map { $0.detectedPort ?? $0.port }
        let externalPIDs = apps.compactMap { $0.externalPID }
        let extraPIDs = apps.flatMap { $0.extraPorts.map(\.pid) }

        for idx in apps.indices {
            apps[idx].isRunning = false
            apps[idx].portStatus = .free
            apps[idx].detectedPort = nil
            apps[idx].externalPID = nil
            apps[idx].backendRunning = false
            apps[idx].extraPorts = []
        }
        refreshProxyRoutes()

        Task.detached {
            for pid in externalPIDs { kill(pid, SIGTERM) }
            for pid in extraPIDs { kill(pid, SIGTERM) }
            for port in portsToKill { SystemClient.killPort(port) }
        }
    }

    func updatePort(for app: DevApp, port: Int) {
        var ports = portStore.load()
        ports[app.name] = port
        portStore.save(ports)
        update(app.name) { $0.port = port }
    }

    func updateGoAlias(for app: DevApp, alias: String) {
        let clean = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        goLinkStore.setAlias(clean, for: app.name)
        update(app.name) { $0.goAlias = clean.isEmpty ? GoLinkStore.defaultAlias(for: app.name) : clean }
        refreshProxyRoutes()
    }

    func setGoLinksEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "goLinksEnabled")
        if enabled {
            proxyServer.start()
            refreshProxyRoutes()
        } else {
            proxyServer.stop()
        }
    }

    var goLinksEnabled: Bool { defaults.bool(forKey: "goLinksEnabled") }

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

    private func refreshProxyRoutes() {
        guard defaults.bool(forKey: "goLinksEnabled") else { return }
        var routes: [String: Int] = [:]
        for app in apps {
            routes[app.goAlias] = app.detectedPort ?? app.port
        }
        proxyServer.updateRoutes(routes)
    }

    private func update(_ name: String, _ mutation: (inout DevApp) -> Void) {
        guard let idx = apps.firstIndex(where: { $0.name == name }) else { return }
        mutation(&apps[idx])
    }
}
