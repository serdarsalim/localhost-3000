import Foundation

struct AppScanner: Sendable {
    let portfolioRoot: URL

    private let excluded: Set<String> = ["dev-dashboard", "localhost-3000", ".git", "node_modules"]

    /// Returns app names in sorted order.
    func scan() -> [String] {
        scanWithPorts().map(\.name)
    }

    struct ScannedApp: Sendable {
        let name: String
        let scriptPort: Int?
        let devScript: String?
        let devScriptName: String?      // npm script name to run for the frontend (dev or dev:frontend)
        let backendScriptName: String?  // optional sibling script (dev:backend) to spawn alongside
    }

    /// Returns app names and any port hardcoded in their dev script.
    func scanWithPorts() -> [ScannedApp] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: portfolioRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { url -> ScannedApp? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let name = url.lastPathComponent
            guard !excluded.contains(name) else { return nil }

            let pkgPath = url.appendingPathComponent("package.json")
            guard fm.fileExists(atPath: pkgPath.path),
                  let data = try? Data(contentsOf: pkgPath),
                  let pkg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scripts = pkg["scripts"] as? [String: Any]
            else { return nil }

            // Prefer "dev"; fall back to "dev:frontend" for split frontend/backend setups.
            let devScriptName: String
            let devScript: String
            if let s = scripts["dev"] as? String {
                devScriptName = "dev"
                devScript = s
            } else if let s = scripts["dev:frontend"] as? String {
                devScriptName = "dev:frontend"
                devScript = s
            } else {
                return nil
            }

            // Only spawn dev:backend separately when the frontend script doesn't already orchestrate it.
            let backendScriptName: String? = (devScriptName == "dev:frontend" && scripts["dev:backend"] != nil)
                ? "dev:backend"
                : nil

            return ScannedApp(
                name: name,
                scriptPort: extractPort(from: devScript),
                devScript: devScript,
                devScriptName: devScriptName,
                backendScriptName: backendScriptName
            )
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
