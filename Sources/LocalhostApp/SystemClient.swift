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
}
