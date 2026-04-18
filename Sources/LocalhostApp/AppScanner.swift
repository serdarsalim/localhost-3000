import Foundation

struct AppScanner: Sendable {
    let portfolioRoot: URL

    private let excluded: Set<String> = ["dev-dashboard", "localhost-3000", ".git", "node_modules"]

    /// Returns app names in sorted order.
    func scan() -> [String] {
        scanWithPorts().map(\.name)
    }

    /// Returns app names and any port hardcoded in their dev script.
    func scanWithPorts() -> [(name: String, scriptPort: Int?)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: portfolioRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { url -> (name: String, scriptPort: Int?)? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let name = url.lastPathComponent
            guard !excluded.contains(name) else { return nil }

            let pkgPath = url.appendingPathComponent("package.json")
            guard fm.fileExists(atPath: pkgPath.path),
                  let data = try? Data(contentsOf: pkgPath),
                  let pkg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scripts = pkg["scripts"] as? [String: Any],
                  let devScript = scripts["dev"] as? String
            else { return nil }

            return (name: name, scriptPort: extractPort(from: devScript))
        }.sorted { $0.name < $1.name }
    }

    /// Parses -p 3001 / --port 3001 / --port=3001 from a dev script string.
    private func extractPort(from script: String) -> Int? {
        let pattern = #"(?:-p|--port[= ])(\d{4,5})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)),
              let range = Range(match.range(at: 1), in: script),
              let port = Int(script[range])
        else { return nil }
        return port
    }
}
