import Foundation

enum AgentOSCompletionPeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: "Today"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .all: "All time"
        }
    }

    func lowerBound(relativeTo now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        return switch self {
        case .today: today
        case .sevenDays: calendar.date(byAdding: .day, value: -6, to: today)
        case .thirtyDays: calendar.date(byAdding: .day, value: -29, to: today)
        case .all: nil
        }
    }
}

enum AgentOSDateMath {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func contains(_ dateValue: String, in period: AgentOSCompletionPeriod, relativeTo now: Date) -> Bool {
        guard period != .all else { return true }
        guard let date = parse(dateValue),
              let lowerBound = period.lowerBound(relativeTo: now) else { return false }
        return date >= lowerBound && date <= now
    }
}
