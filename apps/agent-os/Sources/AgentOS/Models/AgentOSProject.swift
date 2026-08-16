import Foundation

struct AgentOSRepository: Codable, Hashable, Sendable {
    let id: String
    let path: String
    let role: String
    let sourceOfTruth: String
    let primaryBranch: String
}

struct AgentOSProject: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let displayName: String
    let status: String
    let root: String
    let repositories: [AgentOSRepository]

    var id: String { key }

    var preferredWorkingDirectory: URL {
        URL(fileURLWithPath: root, isDirectory: true)
    }
}
