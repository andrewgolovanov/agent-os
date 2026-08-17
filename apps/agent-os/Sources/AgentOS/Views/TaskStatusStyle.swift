import SwiftUI

extension TaskStatus {
    var tint: Color {
        switch self {
        case .inbox:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(82, 82, 82), dark: AgentOSTheme.rgb(161, 161, 170))
        case .planned:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(109, 40, 217), dark: AgentOSTheme.rgb(167, 139, 250))
        case .active:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(21, 128, 61), dark: AgentOSTheme.rgb(74, 222, 128))
        case .waiting:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(180, 83, 9), dark: AgentOSTheme.rgb(251, 191, 36))
        case .review:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(37, 99, 235), dark: AgentOSTheme.rgb(96, 165, 250))
        case .done:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(4, 120, 87), dark: AgentOSTheme.rgb(52, 211, 153))
        case .cancelled:
            AgentOSTheme.adaptive(light: AgentOSTheme.rgb(225, 29, 72), dark: AgentOSTheme.rgb(251, 113, 133))
        }
    }
}
