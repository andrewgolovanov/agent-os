import Foundation

enum AgentOSTimeFormatter {
    static func compact(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        guard safeSeconds >= 60 else {
            return safeSeconds == 0 ? "0 min" : "<1 min"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60

        if hours > 0, minutes > 0 {
            return "\(hours) hr \(minutes) min"
        }
        if hours > 0 {
            return "\(hours) hr"
        }
        return "\(minutes) min"
    }
}
