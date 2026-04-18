import Foundation
import Network

// Runs on port 9080. pf redirects :80 → :9080 so "go/alias" works in the browser.
// Returns a 302 redirect to localhost:<port> — simple, no content proxying needed.

final class ProxyServer: @unchecked Sendable {
    static let proxyPort: UInt16 = 9080

    private var listener: NWListener?
    private(set) var isRunning = false
    private var routes: [String: Int] = [:]  // goAlias → port
    private let lock = NSLock()

    func start() {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.proxyPort)!) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.lock.lock()
            let snapshot = self.routes
            self.lock.unlock()
            Task.detached { ProxyServer.handle(connection, routes: snapshot) }
        }
        listener.start(queue: .global(qos: .utility))
        self.listener = listener
        self.isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    func updateRoutes(_ newRoutes: [String: Int]) {
        lock.lock()
        routes = newRoutes
        lock.unlock()
    }

    private static func handle(_ connection: NWConnection, routes: [String: Int]) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            let requestStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let firstLine = requestStr.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.split(separator: " ")

            let response: String
            if parts.count >= 2 {
                let fullPath = String(parts[1])
                let segments = fullPath.split(separator: "/", omittingEmptySubsequences: true)
                let alias = segments.first.map(String.init) ?? ""
                let tail = segments.dropFirst().joined(separator: "/")
                let targetPath = tail.isEmpty ? "/" : "/\(tail)"

                if let port = routes[alias] {
                    response = "HTTP/1.1 302 Found\r\nLocation: http://localhost:\(port)\(targetPath)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                } else if alias.isEmpty {
                    let list = routes.sorted { $0.key < $1.key }
                        .map { "  go/\($0.key)  →  localhost:\($0.value)" }
                        .joined(separator: "\n")
                    let body = "Localhost 3000 — go/ links\n\n\(list.isEmpty ? "(none configured)" : list)"
                    response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                } else {
                    let body = "go/\(alias) is not configured in Localhost 3000."
                    response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                }
            } else {
                response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            }

            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
