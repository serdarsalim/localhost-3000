import AppKit
import Darwin

enum SystemClient {
    static func lanIPAddress() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "localhost" }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let current = ptr {
            let iface = current.pointee
            if iface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: iface.ifa_name) == "en0" {
                var addr = iface.ifa_addr.pointee
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&addr, socklen_t(iface.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                return String(cString: host)
            }
            ptr = current.pointee.ifa_next
        }
        return "localhost"
    }

    static func copyNetworkURL(port: Int) {
        let ip = lanIPAddress()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://\(ip):\(port)", forType: .string)
    }

    static func openTerminal(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        try? process.run()
    }

    static func openVSCode(at url: URL) {
        let code = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: code)
        process.arguments = [url.path]
        try? process.run()
    }

    static func openFinder(at url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func openBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func isPortListening(_ port: Int) -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).byteSwapped
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }

    // Find all $USER-owned processes listening on TCP, mapped to cwd + command line.
    // Returns one entry per (pid, port). IPv4/IPv6 duplicates are collapsed.
    static func detectRunningServers() -> [DetectedServer] {
        let user = NSUserName()

        // Step 1: every $USER-owned listening TCP socket.
        // -a is critical: lsof selection flags are OR'd by default, so without
        // it this returns "all of $USER's open files" PLUS "all TCP listeners",
        // flooding output and blowing past the runCommand timeout.
        let listenLines = runCommand("/usr/sbin/lsof", ["-a", "-u", user, "-iTCP", "-sTCP:LISTEN", "-nP"])
            .components(separatedBy: "\n").dropFirst()
        var pidPorts: [(pid: Int32, port: Int, shortCmd: String)] = []
        var seen = Set<String>()
        for line in listenLines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9, let pid = Int32(parts[1]) else { continue }
            let shortCmd = String(parts[0])
            let nameField = String(parts[8])
            guard let port = nameField.split(separator: ":").last.flatMap({ Int($0) }) else { continue }
            let key = "\(pid):\(port)"
            if seen.contains(key) { continue }
            seen.insert(key)
            pidPorts.append((pid, port, shortCmd))
        }
        guard !pidPorts.isEmpty else { return [] }

        let uniquePids = Set(pidPorts.map { $0.pid })
        let pidList = uniquePids.map { "\($0)" }.joined(separator: ",")

        // Step 2: cwd per pid
        let cwdLines = runCommand("/usr/sbin/lsof", ["-p", pidList, "-a", "-d", "cwd", "-Fn"])
            .components(separatedBy: "\n")
        var cwds: [Int32: String] = [:]
        var currentPid: Int32 = 0
        for line in cwdLines {
            if line.hasPrefix("p"), let pid = Int32(line.dropFirst()) {
                currentPid = pid
            } else if line.hasPrefix("n"), currentPid != 0 {
                let dir = String(line.dropFirst())
                if !dir.isEmpty { cwds[currentPid] = dir }
            }
        }

        // Step 3: full command line per pid
        let commands = fetchCommands(for: pidList)

        return pidPorts.map { item in
            DetectedServer(
                pid: item.pid,
                port: item.port,
                directory: cwds[item.pid] ?? "",
                command: commands[item.pid] ?? item.shortCmd
            )
        }
    }

    private static func fetchCommands(for pidList: String) -> [Int32: String] {
        let output = runCommand("/bin/ps", ["-p", pidList, "-o", "pid=,command="])
        var result: [Int32: String] = [:]
        for raw in output.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            result[pid] = String(parts[1])
        }
        return result
    }

    static func killPort(_ port: Int) {
        let output = runCommand("/usr/sbin/lsof", ["-ti", "TCP:\(port)"])
        for pidStr in output.components(separatedBy: .newlines) {
            let trimmed = pidStr.trimmingCharacters(in: .whitespaces)
            if let pid = Int32(trimmed), pid > 0 {
                kill(pid, SIGTERM)
            }
        }
    }

    private static func runCommand(_ path: String, _ args: [String], timeout: TimeInterval = 4) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        let sem = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sem.signal() }
        try? p.run()
        if sem.wait(timeout: .now() + timeout) == .timedOut { p.terminate() }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

struct DetectedServer: Sendable {
    let pid: Int32
    let port: Int
    let directory: String
    let command: String
}
