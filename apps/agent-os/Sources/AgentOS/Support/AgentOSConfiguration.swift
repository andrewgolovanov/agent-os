import Foundation

struct AgentOSConfiguration: Sendable {
    let sourceURL: URL
    let homeURL: URL

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> AgentOSConfiguration {
        let defaultHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-os", isDirectory: true)
        let legacyRoot = absoluteURL(environment["WORKSPACE_CONSOLE_ROOT"])
        let home = absoluteURL(environment["AGENT_OS_HOME"])
            ?? legacyRoot
            ?? activeHome()
            ?? defaultHome

        if let source = absoluteURL(environment["AGENT_OS_SOURCE_ROOT"])
            ?? absoluteURL(environment["WORKSPACE_CONSOLE_SOURCE_ROOT"])
            ?? legacyRoot
            ?? sourcePointer(in: home)
        {
            return AgentOSConfiguration(sourceURL: source, homeURL: home)
        }

        return AgentOSConfiguration(sourceURL: home, homeURL: home)
    }

    private static func absoluteURL(_ value: String?) -> URL? {
        guard let value, value.hasPrefix("/"), value != "/" else { return nil }
        return URL(fileURLWithPath: value, isDirectory: true).standardizedFileURL
    }

    private static func sourcePointer(in home: URL) -> URL? {
        let pointer = home.appendingPathComponent("source-path", isDirectory: false)
        guard let content = try? String(contentsOf: pointer, encoding: .utf8) else { return nil }
        return absoluteURL(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func activeHome() -> URL? {
        let pointer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("agent-os", isDirectory: true)
            .appendingPathComponent("home", isDirectory: false)
        guard let content = try? String(contentsOf: pointer, encoding: .utf8) else { return nil }
        return absoluteURL(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
