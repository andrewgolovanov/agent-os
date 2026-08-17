import SwiftUI

enum AgentOSAppearance: String, CaseIterable, Sendable {
    case light
    case dark

    static let storageKey = "agent-os.appearance"

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var toggled: AgentOSAppearance {
        self == .dark ? .light : .dark
    }

    var toggleLabel: String {
        switch self {
        case .light: "Use dark appearance"
        case .dark: "Use light appearance"
        }
    }

    var toggleSystemImage: String {
        switch self {
        case .light: "moon"
        case .dark: "sun.max"
        }
    }

    static func resolved(arguments: [String], storedValue: String) -> AgentOSAppearance {
        if arguments.contains("--force-light-appearance") { return .light }
        if arguments.contains("--force-dark-appearance") { return .dark }
        return AgentOSAppearance(rawValue: storedValue) ?? .dark
    }
}
