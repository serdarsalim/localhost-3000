import Foundation

struct AppScanner: Sendable {
    let portfolioRoot: URL

    private let excluded: Set<String> = ["dev-dashboard", "localhost-3000", ".git", "node_modules"]

    func scan() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: portfolioRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let name = url.lastPathComponent
            guard !excluded.contains(name) else { return nil }

            let pkgPath = url.appendingPathComponent("package.json")
            guard fm.fileExists(atPath: pkgPath.path),
                  let data = try? Data(contentsOf: pkgPath),
                  let pkg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scripts = pkg["scripts"] as? [String: Any],
                  scripts["dev"] != nil
            else { return nil }

            return name
        }.sorted()
    }
}
