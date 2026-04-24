import Foundation
import Combine

/// In-memory ring buffer of log lines captured from a running process.
/// SwiftUI can observe `revision` to refresh when new lines arrive.
@MainActor
final class LogBuffer: ObservableObject {
    private(set) var lines: [String] = []
    @Published private(set) var revision: Int = 0
    /// Assigned port for this app — used by the log viewer to surface
    /// "kill what's on this port" affordances when the process dies fast.
    @Published var assignedPort: Int = 0
    /// True when the last run exited within a few seconds of starting —
    /// almost always a port-conflict or stuck-sidecar situation.
    @Published var quickExit: Bool = false
    private let capacity: Int
    private var startedAt: Date?

    init(capacity: Int = 3000) {
        self.capacity = capacity
    }

    func markStarted(port: Int) {
        assignedPort = port
        startedAt = Date()
        quickExit = false
    }

    func markEnded() {
        if let started = startedAt, Date().timeIntervalSince(started) < 5.0 {
            quickExit = true
        }
        startedAt = nil
    }

    func append(_ chunk: String) {
        let incoming = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for line in incoming where !line.isEmpty {
            lines.append(line)
        }
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
        revision &+= 1
    }

    func clear() {
        lines.removeAll()
        revision &+= 1
    }

    /// Ports mentioned in recent log output (e.g. "port 3210", ":5173").
    /// Used to surface "kill whatever's stuck on port N" suggestions — extracting
    /// data, not interpreting error phrases, so framework-agnostic.
    var mentionedPorts: [Int] {
        let text = lines.suffix(30).joined(separator: "\n")
        let pattern = #"\b(?:port\s+|:)(\d{4,5})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<Int>()
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let m = match, m.numberOfRanges > 1,
                  let r = Range(m.range(at: 1), in: text),
                  let port = Int(text[r]),
                  port >= 1024, port <= 65535 else { return }
            found.insert(port)
        }
        return Array(found).sorted()
    }

    var joined: String { lines.joined(separator: "\n") }
}

@MainActor
final class ProcessManager {
    private var running: [String: Process] = [:]
    private var stopping: Set<String> = []
    private var buffers: [String: LogBuffer] = [:]
    var onTerminated: ((String) -> Void)?

    func logBuffer(for name: String) -> LogBuffer {
        if let existing = buffers[name] { return existing }
        let buf = LogBuffer()
        buffers[name] = buf
        return buf
    }

    func start(name: String, port: Int, in directory: URL, devScript: String? = nil) {
        guard !(running[name]?.isRunning == true) else { return }

        let buffer = logBuffer(for: name)
        buffer.clear()
        buffer.markStarted(port: port)
        buffer.append("$ starting \(name) on port \(port)")

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
            command = patchPort(in: script, to: port)
        } else {
            command = "npm run dev"
        }
        // Run interactively (no `exec`) so the zsh PID is the process leader.
        // Swift's Process puts the child in a new process group, so killing that
        // group on stop reliably reaps compound dev scripts (convex+vite, concurrently, etc.).
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        attachReader(outPipe.fileHandleForReading, to: buffer)
        attachReader(errPipe.fileHandleForReading, to: buffer)

        process.terminationHandler = { [weak self, name] proc in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let unexpected = !self.stopping.contains(name)
                self.stopping.remove(name)
                self.running.removeValue(forKey: name)
                let reason = proc.terminationReason == .uncaughtSignal ? "signal" : "exit"
                self.buffers[name]?.append("$ process ended (\(reason) \(proc.terminationStatus))")
                self.buffers[name]?.markEnded()
                if unexpected { self.onTerminated?(name) }
            }
        }

        do {
            try process.run()
            running[name] = process
        } catch {
            buffer.append("$ failed to start: \(error.localizedDescription)")
        }
    }

    func stop(name: String) {
        stopping.insert(name)
        if let process = running[name] {
            terminateTree(process)
        }
        running.removeValue(forKey: name)
    }

    func stopAll() {
        for name in running.keys { stopping.insert(name) }
        for process in running.values { terminateTree(process) }
        running.removeAll()
    }

    func isRunning(name: String) -> Bool {
        running[name]?.isRunning == true
    }

    /// Signal the entire descendant tree (npm → convex → vite, etc.). `process.terminate()`
    /// only hits the direct child, which doesn't reliably forward signals to grandchildren,
    /// leaving zombies that hold ports and deployment locks.
    private func terminateTree(_ process: Process) {
        let pid = process.processIdentifier
        guard pid > 0 else {
            process.terminate()
            return
        }
        let descendants = Self.descendantPIDs(of: pid)
        // Signal leaves first so parents can observe and exit cleanly.
        for p in descendants.reversed() { kill(p, SIGTERM) }
        kill(pid, SIGTERM)

        let allPIDs = [pid] + descendants
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            for p in allPIDs { kill(p, SIGKILL) }
        }
    }

    /// Returns PIDs of all descendants of `root`, breadth-first. Uses `pgrep -P` which
    /// is available on macOS by default.
    private static func descendantPIDs(of root: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var queue: [pid_t] = [root]
        while !queue.isEmpty {
            let parent = queue.removeFirst()
            let children = childPIDs(of: parent)
            result.append(contentsOf: children)
            queue.append(contentsOf: children)
        }
        return result
    }

    private static func childPIDs(of parent: pid_t) -> [pid_t] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-P", "\(parent)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return [] }
        return str.split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func attachReader(_ handle: FileHandle, to buffer: LogBuffer) {
        handle.readabilityHandler = { [weak buffer] fh in
            let data = fh.availableData
            if data.isEmpty {
                fh.readabilityHandler = nil
                return
            }
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            Task { @MainActor [weak buffer] in
                buffer?.append(chunk)
            }
        }
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
