import Foundation

struct AgentOSProjectSyncReport: Decodable, Sendable {
    let applied: Bool
    let discoveredCount: Int
    let eligibleCount: Int
    let registeredCount: Int
    let enrichedCount: Int
    let refreshedCount: Int
    let preservedCount: Int
    let skippedCount: Int
    let linkedSlackChannelCount: Int
    let attributedSlackTaskCount: Int

    enum CodingKeys: String, CodingKey {
        case applied
        case discoveredCount = "discovered_count"
        case eligibleCount = "eligible_count"
        case registeredCount = "registered_count"
        case enrichedCount = "enriched_count"
        case refreshedCount = "refreshed_count"
        case preservedCount = "preserved_count"
        case skippedCount = "skipped_count"
        case linkedSlackChannelCount = "linked_slack_channel_count"
        case attributedSlackTaskCount = "attributed_slack_task_count"
    }

    init(
        applied: Bool,
        discoveredCount: Int,
        eligibleCount: Int,
        registeredCount: Int,
        enrichedCount: Int,
        refreshedCount: Int,
        preservedCount: Int,
        skippedCount: Int,
        linkedSlackChannelCount: Int,
        attributedSlackTaskCount: Int
    ) {
        self.applied = applied
        self.discoveredCount = discoveredCount
        self.eligibleCount = eligibleCount
        self.registeredCount = registeredCount
        self.enrichedCount = enrichedCount
        self.refreshedCount = refreshedCount
        self.preservedCount = preservedCount
        self.skippedCount = skippedCount
        self.linkedSlackChannelCount = linkedSlackChannelCount
        self.attributedSlackTaskCount = attributedSlackTaskCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applied = try container.decode(Bool.self, forKey: .applied)
        discoveredCount = try container.decode(Int.self, forKey: .discoveredCount)
        eligibleCount = try container.decode(Int.self, forKey: .eligibleCount)
        registeredCount = try container.decode(Int.self, forKey: .registeredCount)
        enrichedCount = try container.decodeIfPresent(Int.self, forKey: .enrichedCount) ?? 0
        refreshedCount = try container.decodeIfPresent(Int.self, forKey: .refreshedCount) ?? 0
        preservedCount = try container.decode(Int.self, forKey: .preservedCount)
        skippedCount = try container.decode(Int.self, forKey: .skippedCount)
        linkedSlackChannelCount = try container.decodeIfPresent(Int.self, forKey: .linkedSlackChannelCount) ?? 0
        attributedSlackTaskCount = try container.decodeIfPresent(Int.self, forKey: .attributedSlackTaskCount) ?? 0
    }
}
