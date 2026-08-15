import Foundation

struct AgentOSSourceLink: Codable, Hashable, Identifiable, Sendable {
    let identity: String
    let url: String

    var id: String { identity }
}

struct AgentOSSources: Codable, Hashable, Sendable {
    let slackThreads: [AgentOSSourceLink]
    let pullRequests: [AgentOSSourceLink]
    let figma: [AgentOSSourceLink]
    let deployments: [AgentOSSourceLink]
    let other: [AgentOSSourceLink]

    var all: [AgentOSSourceLink] {
        slackThreads + pullRequests + figma + deployments + other
    }

    private enum CodingKeys: String, CodingKey {
        case slackThreads = "slack_threads"
        case pullRequests = "pull_requests"
        case figma
        case deployments
        case other
    }
}

struct CodexMembership: Codable, Hashable, Identifiable, Sendable {
    let threadID: String
    let url: String
    let role: String
    let status: String
    let origin: String
    let project: String?
    let title: String?

    var id: String { threadID }

    private enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case url
        case role
        case status
        case origin
        case project
        case title
    }
}

struct AgentOSActivity: Codable, Hashable, Sendable {
    let totalSeconds: Int

    private enum CodingKeys: String, CodingKey {
        case totalSeconds = "total_seconds"
    }
}

struct AgentOSTask: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let projects: [String]
    let kind: String
    let status: TaskStatus
    let goal: String
    let summary: String
    let constraints: [String]
    let nextAction: String
    let waitingOn: String?
    let sources: AgentOSSources
    let codexThreads: [CodexMembership]
    let activity: AgentOSActivity
    let createdAt: String
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case projects
        case kind
        case status
        case goal
        case summary
        case constraints
        case nextAction = "next_action"
        case waitingOn = "waiting_on"
        case sources
        case codexThreads = "codex_threads"
        case activity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        projects = try container.decode([String].self, forKey: .projects)
        kind = try container.decode(String.self, forKey: .kind)
        status = try container.decode(TaskStatus.self, forKey: .status)
        goal = try container.decode(String.self, forKey: .goal)
        summary = try container.decode(String.self, forKey: .summary)
        constraints = try container.decode([String].self, forKey: .constraints)
        nextAction = try container.decode(String.self, forKey: .nextAction)
        waitingOn = try container.decodeIfPresent(String.self, forKey: .waitingOn)
        sources = try container.decode(AgentOSSources.self, forKey: .sources)
        codexThreads = try container.decode([CodexMembership].self, forKey: .codexThreads)
        activity = try container.decodeIfPresent(AgentOSActivity.self, forKey: .activity)
            ?? AgentOSActivity(totalSeconds: 0)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}

struct AgentOSSnapshot: Sendable {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
}
