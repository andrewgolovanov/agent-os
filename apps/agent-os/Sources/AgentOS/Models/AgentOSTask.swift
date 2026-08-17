import Foundation

struct AgentOSSourceLink: Codable, Hashable, Identifiable, Sendable {
    let identity: String
    let url: String

    var id: String { identity }
}

enum AgentOSSourceKind: String, Hashable, Sendable {
    case slackThread
    case pullRequest
    case figma
    case deployment
    case other
}

struct AgentOSSourceItem: Hashable, Identifiable, Sendable {
    let link: AgentOSSourceLink
    let kind: AgentOSSourceKind

    var id: String { "\(kind.rawValue):\(link.identity)" }
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

    var items: [AgentOSSourceItem] {
        slackThreads.map { AgentOSSourceItem(link: $0, kind: .slackThread) }
            + pullRequests.map { AgentOSSourceItem(link: $0, kind: .pullRequest) }
            + figma.map { AgentOSSourceItem(link: $0, kind: .figma) }
            + deployments.map { AgentOSSourceItem(link: $0, kind: .deployment) }
            + other.map { AgentOSSourceItem(link: $0, kind: .other) }
    }

    var pullRequestItems: [AgentOSSourceItem] {
        pullRequests.map { AgentOSSourceItem(link: $0, kind: .pullRequest) }
    }

    var supportingItems: [AgentOSSourceItem] {
        items.filter { $0.kind != .pullRequest }
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

struct AgentOSActivityTurn: Codable, Hashable, Sendable {
    let startedAt: String
    let stoppedAt: String?
    let durationSeconds: Int?

    private enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case durationSeconds = "duration_seconds"
    }
}

struct AgentOSActivity: Codable, Hashable, Sendable {
    let totalSeconds: Int
    let turns: [AgentOSActivityTurn]

    init(totalSeconds: Int, turns: [AgentOSActivityTurn] = []) {
        self.totalSeconds = totalSeconds
        self.turns = turns
    }

    private enum CodingKeys: String, CodingKey {
        case totalSeconds = "total_seconds"
        case turns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalSeconds = try container.decode(Int.self, forKey: .totalSeconds)
        turns = try container.decodeIfPresent([AgentOSActivityTurn].self, forKey: .turns) ?? []
    }
}

enum AgentOSCompletionFollowUpStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case pending
    case sent
    case notRequired = "not_required"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .sent: "Sent"
        case .notRequired: "Not required"
        }
    }
}

struct AgentOSCompletion: Codable, Hashable, Sendable {
    let completedAt: String?
    let followUpStatus: AgentOSCompletionFollowUpStatus
    let followUpSentAt: String?

    private enum CodingKeys: String, CodingKey {
        case completedAt = "completed_at"
        case followUpStatus = "follow_up_status"
        case followUpSentAt = "follow_up_sent_at"
    }
}

struct AgentOSLabel: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let name: String
    let kind: String

    var id: String { key }
}

struct AgentOSTask: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let projects: [String]
    let labels: [AgentOSLabel]
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
    let completion: AgentOSCompletion?
    let createdAt: String
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case projects
        case labels
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
        case completion
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        projects = try container.decode([String].self, forKey: .projects)
        labels = try container.decodeIfPresent([AgentOSLabel].self, forKey: .labels) ?? []
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
        completion = try container.decodeIfPresent(AgentOSCompletion.self, forKey: .completion)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    var completionFollowUpStatus: AgentOSCompletionFollowUpStatus {
        guard status == .done else { return .notRequired }
        if let completion { return completion.followUpStatus }
        return sources.slackThreads.isEmpty ? .notRequired : .pending
    }

    var completedAt: String {
        completion?.completedAt ?? updatedAt
    }
}

struct AgentOSSnapshot: Sendable {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
}
