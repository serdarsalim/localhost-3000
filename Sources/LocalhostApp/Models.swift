import Foundation

enum PortStatus: Sendable, Hashable {
    case free      // stopped, port available
    case running   // we started it, port is responding
    case external  // something else is listening on this port
    case crashed   // we started it but it stopped responding
}

struct DevApp: Identifiable, Sendable, Hashable {
    var id: String { name }
    let name: String
    var port: Int
    var isRunning: Bool
    var portStatus: PortStatus
    var gitStatus: GitStatus
}

struct GitStatus: Sendable, Hashable {
    var isRepo: Bool
    var uncommittedCount: Int

    static let unknown = GitStatus(isRepo: false, uncommittedCount: 0)
}
