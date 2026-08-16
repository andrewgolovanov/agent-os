import Foundation

enum AgentOSDeepLinkDestination: Equatable {
    case board
    case focus
    case done
}

enum AgentOSDeepLink {
    static let scheme = "agent-os"

    static func destination(for url: URL) -> AgentOSDeepLinkDestination? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        switch url.host?.lowercased() {
        case "board": return .board
        case "focus": return .focus
        case "done", "history", "time": return .done
        default: return nil
        }
    }
}
