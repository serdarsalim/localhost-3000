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

    // Find all node processes listening on TCP, mapped to their working directories.
    static func detectRunningServers() -> [DetectedServer] {
        // Step 1: (pid -> port) for listening node processes
        let listenLines = runCommand("/usr/sbin/lsof", ["-c", "node", "-iTCP", "-sTCP:LISTEN", "-nP"])
            .components(separatedBy: "\n").dropFirst()
        var pidPorts: [Int32: Int] = [:]
        for line in listenLines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9, let pid = Int32(parts[1]) else { continue }
            let name = String(parts[8])
            if let port = name.split(separator: ":").last.flatMap({ Int($0) }) {
                pidPorts[pid] = port
            }
        }
        guard !pidPorts.isEmpty else { return [] }

        // Step 2: (pid -> cwd) for those PIDs
        let pidList = pidPorts.keys.map { "\($0)" }.joined(separator: ",")
        let cwdLines = runCommand("/usr/sbin/lsof", ["-p", pidList, "-a", "-d", "cwd", "-Fn"])
            .components(separatedBy: "\n")

        var results: [DetectedServer] = []
        var currentPid: Int32 = 0
        for line in cwdLines {
            if line.hasPrefix("p"), let pid = Int32(line.dropFirst()) {
                currentPid = pid
            } else if line.hasPrefix("n"), currentPid != 0, let port = pidPorts[currentPid] {
                let dir = String(line.dropFirst())
                if !dir.isEmpty {
                    results.append(DetectedServer(pid: currentPid, port: port, directory: dir))
                }
            }
        }
        return results
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
}
