import Foundation

struct AgentOSUpdateStatus: Decodable, Sendable {
    let updateAvailable: Bool?
    let updated: Bool?
    let source: Source
    let plugin: Plugin

    struct Source: Decodable, Sendable {
        let configured: Bool
        let currentVersion: String?
        let latestVersion: String?
        let updateAvailable: Bool
        let action: String
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case configured
            case currentVersion = "current_version"
            case latestVersion = "latest_version"
            case updateAvailable = "update_available"
            case action
            case reason
        }
    }

    struct Plugin: Decodable, Sendable {
        let configured: Bool
        let installed: Bool
        let installedVersion: String?
        let sourceVersion: String?
        let refreshRequired: Bool
        let updated: Bool
        let action: String
        let reason: String?
        let marketplaceSource: String?
        let marketplaceRef: String?
        let targetRef: String?

        var canInstallUpdate: Bool {
            refreshRequired && ["install-packaged-release", "refresh-after-core"].contains(action)
        }

        enum CodingKeys: String, CodingKey {
            case configured
            case installed
            case installedVersion = "installed_version"
            case sourceVersion = "source_version"
            case refreshRequired = "refresh_required"
            case updated
            case action
            case reason
            case marketplaceSource = "marketplace_source"
            case marketplaceRef = "marketplace_ref"
            case targetRef = "target_ref"
        }
    }

    enum CodingKeys: String, CodingKey {
        case updateAvailable = "update_available"
        case updated
        case source
        case plugin
    }
}
