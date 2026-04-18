import Foundation
import Network

// Runs on port 9080. Routes by subdomain: slm.localhost:9080 → localhost:<port>
// No system setup needed — browsers resolve *.localhost to 127.0.0.1 natively.

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
            let lines = requestStr.components(separatedBy: "\r\n")
            let firstLine = lines.first ?? ""

            // Extract path from "GET /path HTTP/1.1"
            let reqParts = firstLine.split(separator: " ")
            let path = reqParts.count >= 2 ? String(reqParts[1]) : "/"

            // Extract subdomain from Host header e.g. "slm.localhost:9080" → "slm"
            let host = lines.first(where: { $0.lowercased().hasPrefix("host:") })
                .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) } ?? ""
            let hostWithoutPort = host.components(separatedBy: ":").first ?? host
            let subdomain = hostWithoutPort.components(separatedBy: ".").first ?? ""

            let response: String
            if let port = routes[subdomain] {
                response = "HTTP/1.1 302 Found\r\nLocation: http://localhost:\(port)\(path)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            } else if subdomain == "localhost" || subdomain.isEmpty {
                let list = routes.sorted { $0.key < $1.key }
                    .map { "  \($0.key).localhost:9080  →  localhost:\($0.value)" }
                    .joined(separator: "\n")
                let body = "Localhost 3000 — go links\n\n\(list.isEmpty ? "(none configured)" : list)"
                response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            } else {
                let body = "\(subdomain).localhost:9080 is not configured in Localhost 3000."
                response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            }

            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
