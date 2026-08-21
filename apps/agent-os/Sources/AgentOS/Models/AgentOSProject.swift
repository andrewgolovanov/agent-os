import Foundation

struct AgentOSRepository: Codable, Hashable, Sendable {
    let id: String
    let path: String
    let role: String
    let sourceOfTruth: String
    let primaryBranch: String
}

struct AgentOSSlackChannel: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String

    var labelKey: String { "slack:\(id)" }
}

struct AgentOSProject: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let displayName: String
    let status: String
    let root: String
    let slackChannels: [AgentOSSlackChannel]
    let repositories: [AgentOSRepository]

    var id: String { key }

    var preferredWorkingDirectory: URL {
        URL(fileURLWithPath: root, isDirectory: true)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case displayName
        case status
        case root
        case slackChannels
        case repositories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        displayName = try container.decode(String.self, forKey: .displayName)
        status = try container.decode(String.self, forKey: .status)
        root = try container.decode(String.self, forKey: .root)
        slackChannels = try container.decodeIfPresent([AgentOSSlackChannel].self, forKey: .slackChannels) ?? []
        repositories = try container.decodeIfPresent([AgentOSRepository].self, forKey: .repositories) ?? []
    }
}
