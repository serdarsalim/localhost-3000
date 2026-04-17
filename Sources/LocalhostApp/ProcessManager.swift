import Foundation

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]

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

        try? process.run()
        running[name] = process
    }

    func stop(name: String) {
        running[name]?.terminate()
        running.removeValue(forKey: name)
    }

    func stopAll() {
        for process in running.values { process.terminate() }
        running.removeAll()
    }

    func isRunning(name: String) -> Bool {
        running[name]?.isRunning == true
    }
}
