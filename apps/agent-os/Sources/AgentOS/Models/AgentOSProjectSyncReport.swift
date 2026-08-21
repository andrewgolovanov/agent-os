import Foundation

struct AgentOSProjectSyncReport: Decodable, Sendable {
    let applied: Bool
    let discoveredCount: Int
    let eligibleCount: Int
    let registeredCount: Int
    let preservedCount: Int
    let skippedCount: Int

    enum CodingKeys: String, CodingKey {
        case applied
        case discoveredCount = "discovered_count"
        case eligibleCount = "eligible_count"
        case registeredCount = "registered_count"
        case preservedCount = "preserved_count"
        case skippedCount = "skipped_count"
    }
}
