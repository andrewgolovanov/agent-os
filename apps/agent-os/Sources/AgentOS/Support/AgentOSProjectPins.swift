import Foundation

enum AgentOSProjectPins {
    static let storageKey = "agent-os.pinned-project-keys"

    static func decode(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return normalized(decoded)
    }

    static func encode(_ keys: [String]) -> String {
        guard let data = try? JSONEncoder().encode(normalized(keys)),
              let value = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return value
    }

    static func toggled(_ key: String, in keys: [String]) -> [String] {
        let keys = normalized(keys)
        if keys.contains(key) {
            return keys.filter { $0 != key }
        }
        return keys + [key]
    }

    private static func normalized(_ keys: [String]) -> [String] {
        var seen = Set<String>()
        return keys.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
