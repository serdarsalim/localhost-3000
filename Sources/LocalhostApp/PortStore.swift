import Foundation

struct PortStore {
    private let key = "appPorts"
    private let defaults = UserDefaults.standard

    func load() -> [String: Int] {
        defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    func save(_ ports: [String: Int]) {
        defaults.set(ports, forKey: key)
    }

    func assign(to appNames: [String]) -> [String: Int] {
        var ports = load()
        var used = Set(ports.values)
        var next = 3001
        for name in appNames {
            if ports[name] == nil {
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
