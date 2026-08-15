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
    let wrapper: String
    let repositories: [AgentOSRepository]

    var id: String { key }

    var preferredWorkingDirectory: URL {
        if let repository = repositories.first {
            return URL(fileURLWithPath: repository.path, isDirectory: true)
        }
        return URL(fileURLWithPath: wrapper, isDirectory: true)
    }
}
