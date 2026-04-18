import Foundation

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]
    private var stopping: Set<String> = []
    var onTerminated: ((String) -> Void)?

    func start(name: String, port: Int, in directory: URL, devScript: String? = nil) {
        guard !(running[name]?.isRunning == true) else { return }

        var env = ProcessInfo.processInfo.environment
        env["PORT"] = "\(port)"
        env["VITE_PORT"] = "\(port)"
        // Include local node_modules/.bin so patched scripts can find binaries
        // (npm adds this automatically; direct script execution needs it explicitly)
        let localBin = directory.appendingPathComponent("node_modules/.bin").path
        let extraPaths = "\(localBin):/opt/homebrew/bin:/usr/local/bin"
        env["PATH"] = "\(extraPaths):\(env["PATH"] ?? "/usr/bin:/bin")"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        // If the dev script hardcodes a port, patch it to use our assigned port
        // so the app's port assignment always wins over the package.json default.
        let command: String
        if let script = devScript, script.contains("-p") || script.contains("--port") {
            let patched = patchPort(in: script, to: port)
            command = "exec \(patched)"
        } else {
            command = "exec npm run dev"
        }
        process.arguments = ["-c", command]
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

    /// Replaces -p PORT / --port PORT / --port=PORT in a dev script string.
    private func patchPort(in script: String, to port: Int) -> String {
        var result = script
        let patterns = [
            (#"(-p\s+)\d{4,5}"#,       "$1\(port)"),
            (#"(--port=)\d{4,5}"#,      "$1\(port)"),
            (#"(--port\s+)\d{4,5}"#,    "$1\(port)")
        ]
        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        return result
    }
}
