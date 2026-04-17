import Foundation

enum PortStatus: Sendable, Hashable {
    case free      // stopped, port available
    case running   // we started it, port is responding
    case detached  // running in this project's directory but started outside the app
    case external  // something else is on the assigned port (different project)
    case crashed   // we started it but it stopped responding
}

struct DevApp: Identifiable, Sendable, Hashable {
    var id: String { name }
    let name: String
    var port: Int
    var isRunning: Bool
    var portStatus: PortStatus
    var detectedPort: Int?   // actual port the server bound to (may differ from assigned)
    var externalPID: Int32?  // PID of a detached process we can kill
    var gitStatus: GitStatus
}

struct GitStatus: Sendable, Hashable {
    var isRepo: Bool
    var uncommittedCount: Int

    static let unknown = GitStatus(isRepo: false, uncommittedCount: 0)
}
