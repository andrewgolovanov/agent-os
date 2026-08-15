import SwiftUI

struct StatusBadge: View {
    let status: TaskStatus
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .imageScale(.small)
            if !compact {
                Text(status.displayName)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(status.tint)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 2)
        .background(status.tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(status.tint.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }
}
