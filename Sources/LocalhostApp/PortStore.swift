import Foundation

struct PortStore {
    private let key = "appPorts"
    private let defaults = UserDefaults.standard

    func load() -> [String: Int] {
        guard let raw = defaults.dictionary(forKey: key) else { return [:] }
        return raw.compactMapValues { $0 as? Int }
    }

    func save(_ ports: [String: Int]) {
        defaults.set(ports, forKey: key)
    }

    /// Assigns ports to app names. For new apps, prefers the port hardcoded in
    /// their dev script (scriptPorts) over auto-incrementing from 3001.
    func assign(to appNames: [String], scriptPorts: [String: Int] = [:]) -> [String: Int] {
        var ports = load()
        var used = Set(ports.values)
        var next = 3001

        for name in appNames {
            guard ports[name] == nil else { continue }

            if let hint = scriptPorts[name], !used.contains(hint) {
                // Respect the port hardcoded in the project's dev script
                ports[name] = hint
                used.insert(hint)
            } else {
                // Auto-assign next free port
                while used.contains(next) { next += 1 }
                ports[name] = next
                used.insert(next)
                next += 1
            }
        }
        save(ports)
        return ports
    }
}
