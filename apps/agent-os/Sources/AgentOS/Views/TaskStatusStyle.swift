import SwiftUI

extension TaskStatus {
    var tint: Color {
        switch self {
        case .inbox: Color(red: 0.631, green: 0.631, blue: 0.667)
        case .planned: Color(red: 0.655, green: 0.545, blue: 0.980)
        case .active: Color(red: 0.290, green: 0.871, blue: 0.502)
        case .waiting: Color(red: 0.984, green: 0.749, blue: 0.141)
        case .review: Color(red: 0.376, green: 0.647, blue: 0.980)
        case .done: Color(red: 0.204, green: 0.827, blue: 0.600)
        case .cancelled: Color(red: 0.984, green: 0.443, blue: 0.522)
        }
    }
}
