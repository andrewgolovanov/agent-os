import SwiftUI

struct StatusBadge: View {
    let status: TaskStatus
    var compact = false

    var body: some View {
        Group {
            if compact {
                compactMarker
            } else {
                labeledBadge
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }

    private var compactMarker: some View {
        Image(systemName: status.systemImage)
            .font(.system(size: 10, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(status.tint)
            .frame(
                width: AgentOSMetrics.statusMarkerDiameter,
                height: AgentOSMetrics.statusMarkerDiameter
            )
            .background(status.tint.opacity(0.12), in: Circle())
            .overlay {
                Circle()
                    .stroke(status.tint.opacity(0.28), lineWidth: 1)
            }
    }

    private var labeledBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .imageScale(.small)
            Text(status.displayName)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(status.tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(status.tint.opacity(0.28), lineWidth: 1)
        }
    }
}
