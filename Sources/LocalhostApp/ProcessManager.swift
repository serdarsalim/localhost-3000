import Foundation

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]
    private var backends: [String: Process] = [:]
    private var stopping: Set<String> = []
    var onTerminated: ((String) -> Void)?

    func start(
        name: String,
        port: Int,
        in directory: URL,
        devScript: String? = nil,
        devScriptName: String? = nil,
        backendScriptName: String? = nil
    ) {
        guard !(running[name]?.isRunning == true) else { return }

        let env = baseEnvironment(port: port, directory: directory)
        let scriptName = devScriptName ?? "dev"

        // Frontend: patch hardcoded port if present, otherwise run via npm.
        let command: String
        if let script = devScript, script.contains("-p") || script.contains("--port") {
            command = "exec \(patchPort(in: script, to: port))"
        } else {
            command = "exec npm run \(scriptName)"
        }

        let frontend = makeProcess(directory: directory, env: env, command: command)
        frontend.terminationHandler = { [weak self, name] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let unexpected = !self.stopping.contains(name)
                self.stopping.remove(name)
                self.running.removeValue(forKey: name)
                // Frontend dying takes the backend down with it.
                if let backend = self.backends.removeValue(forKey: name), backend.isRunning {
                    backend.terminate()
                }
                if unexpected { self.onTerminated?(name) }
            }
        }

        // Spawn the backend sidecar first so the frontend can connect on boot.
        // Refuse to spawn it if the script hardcodes a port — those are real servers
        // that need their own port management, not Convex-style network clients.
        if let backendName = backendScriptName {
            let backendCommand = "exec npm run \(backendName)"
            let backend = makeProcess(directory: directory, env: env, command: backendCommand)
            backend.terminationHandler = { [weak self, name] _ in
                Task { @MainActor [weak self] in
                    self?.backends.removeValue(forKey: name)
                }
            }
            try? backend.run()
            backends[name] = backend
        }

        try? frontend.run()
        running[name] = frontend
    }

    func stop(name: String) {
        stopping.insert(name)
        running[name]?.terminate()
        running.removeValue(forKey: name)
        if let backend = backends.removeValue(forKey: name), backend.isRunning {
            backend.terminate()
        }
    }

    func stopAll() {
        for name in running.keys { stopping.insert(name) }
        for process in running.values { process.terminate() }
        for process in backends.values where process.isRunning { process.terminate() }
        running.removeAll()
        backends.removeAll()
    }

    func isRunning(name: String) -> Bool {
        running[name]?.isRunning == true
    }

    func isBackendRunning(name: String) -> Bool {
        backends[name]?.isRunning == true
    }

    private func baseEnvironment(port: Int, directory: URL) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = "\(port)"
        env["VITE_PORT"] = "\(port)"
        let localBin = directory.appendingPathComponent("node_modules/.bin").path
        let extraPaths = "\(localBin):/opt/homebrew/bin:/usr/local/bin"
        env["PATH"] = "\(extraPaths):\(env["PATH"] ?? "/usr/bin:/bin")"
        return env
    }

    private func makeProcess(directory: URL, env: [String: String], command: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
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
