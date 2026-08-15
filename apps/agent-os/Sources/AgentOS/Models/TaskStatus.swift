import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case inbox
    case planned
    case active
    case waiting
    case review
    case done
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .planned: "Planned"
        case .active: "Active"
        case .waiting: "Waiting"
        case .review: "Review"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray"
        case .planned: "calendar"
        case .active: "bolt.fill"
        case .waiting: "pause.circle"
        case .review: "checkmark.bubble"
        case .done: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    var isUnfinished: Bool {
        self != .done && self != .cancelled
    }

    static let boardColumns: [TaskStatus] = [.inbox, .planned, .active, .waiting, .review]
}
