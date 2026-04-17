import Foundation

struct DevApp: Identifiable, Sendable, Hashable {
    var id: String { name }
    let name: String
    var port: Int
    var isRunning: Bool
    var gitStatus: GitStatus
}

struct GitStatus: Sendable, Hashable {
    var isRepo: Bool
    var uncommittedCount: Int

    static let unknown = GitStatus(isRepo: false, uncommittedCount: 0)
}
