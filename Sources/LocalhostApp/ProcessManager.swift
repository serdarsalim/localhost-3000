import Foundation

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]
    private var backends: [String: Process] = [:]
    private var stopping: Set<String> = []
    private var stderrBuffers: [String: StderrBuffer] = [:]
    private(set) var crashLogs: [String: String] = [:]  // name → last stderr on unexpected exit

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

        let command: String
        if let script = devScript, script.contains("-p") || script.contains("--port") {
            command = "exec \(patchPort(in: script, to: port))"
        } else {
            command = "exec npm run \(scriptName)"
        }

        // Clear any previous crash log when restarting.
        crashLogs.removeValue(forKey: name)

        let buffer = StderrBuffer()
        stderrBuffers[name] = buffer

        let frontend = makeProcess(directory: directory, env: env, command: command, stderrBuffer: buffer)
        frontend.terminationHandler = { [weak self, name] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let unexpected = !self.stopping.contains(name)
                self.stopping.remove(name)
                self.running.removeValue(forKey: name)
                if let backend = self.backends.removeValue(forKey: name), backend.isRunning {
                    backend.terminate()
                }
                if unexpected {
                    // Capture whatever the process last wrote to stderr.
                    if let log = self.stderrBuffers[name]?.tail() {
                        self.crashLogs[name] = log
                    }
                    self.stderrBuffers.removeValue(forKey: name)
                    self.onTerminated?(name)
                } else {
                    self.stderrBuffers.removeValue(forKey: name)
                }
            }
        }

        if let backendName = backendScriptName {
            let backendCommand = "exec npm run \(backendName)"
            let backend = makeProcess(directory: directory, env: env, command: backendCommand, stderrBuffer: nil)
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
        crashLogs.removeValue(forKey: name)
        running[name]?.terminate()
        running.removeValue(forKey: name)
        stderrBuffers.removeValue(forKey: name)
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
        stderrBuffers.removeAll()
        crashLogs.removeAll()
    }

    func isRunning(name: String) -> Bool {
        running[name]?.isRunning == true
    }

    func isBackendRunning(name: String) -> Bool {
        backends[name]?.isRunning == true
    }

    func crashLog(for name: String) -> String? {
        crashLogs[name]
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

    private func makeProcess(directory: URL, env: [String: String], command: String, stderrBuffer: StderrBuffer?) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        process.environment = env
        process.standardOutput = FileHandle.nullDevice

        if let buffer = stderrBuffer {
            let pipe = Pipe()
            process.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                buffer.append(text)
            }
        } else {
            process.standardError = FileHandle.nullDevice
        }

        return process
    }

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

// Collects stderr lines in a ring buffer; thread-safe via NSLock.
final class StderrBuffer: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()
    private let maxLines = 60

    func append(_ text: String) {
        let incoming = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        lock.lock()
        lines.append(contentsOf: incoming)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        lock.unlock()
    }

    func tail() -> String? {
        lock.lock()
        let result = lines.isEmpty ? nil : lines.joined(separator: "\n")
        lock.unlock()
        return result
    }
}
