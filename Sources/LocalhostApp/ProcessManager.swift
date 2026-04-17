import Foundation

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]
    private var stopping: Set<String> = []
    var onTerminated: ((String) -> Void)?

    func start(name: String, port: Int, in directory: URL) {
        guard !(running[name]?.isRunning == true) else { return }

        var env = ProcessInfo.processInfo.environment
        env["PORT"] = "\(port)"
        env["VITE_PORT"] = "\(port)"
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin"
        env["PATH"] = "\(extraPaths):\(env["PATH"] ?? "/usr/bin:/bin")"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // exec replaces the shell with npm so terminate() hits npm directly
        process.arguments = ["-c", "exec npm run dev"]
        process.currentDirectoryURL = directory
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        process.terminationHandler = { [weak self, name] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let unexpected = !self.stopping.contains(name)
                self.stopping.remove(name)
                self.running.removeValue(forKey: name)
                if unexpected { self.onTerminated?(name) }
            }
        }

        try? process.run()
        running[name] = process
    }

    func stop(name: String) {
        stopping.insert(name)
        running[name]?.terminate()
        running.removeValue(forKey: name)
    }

    func stopAll() {
        for name in running.keys { stopping.insert(name) }
        for process in running.values { process.terminate() }
        running.removeAll()
    }

    func isRunning(name: String) -> Bool {
        running[name]?.isRunning == true
    }
}
