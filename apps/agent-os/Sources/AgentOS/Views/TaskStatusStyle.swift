import SwiftUI

extension TaskStatus {
    var tint: Color {
        switch self {
        case .inbox: .secondary
        case .planned: .blue
        case .active: .orange
        case .waiting: .purple
        case .review: .teal
        case .done: .green
        case .cancelled: .red
        }
    }
}
