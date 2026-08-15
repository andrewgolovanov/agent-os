import SwiftUI

struct TaskCardView: View {
    let task: AgentOSTask
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(task.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AgentOSTheme.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Label(AgentOSTimeFormatter.compact(seconds: task.activity.totalSeconds), systemImage: "clock")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .fixedSize()
            }

            if !task.summary.isEmpty {
                Text(task.summary)
                    .font(.callout)
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                ForEach(task.projects.prefix(2), id: \.self) { project in
                    Text(project)
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AgentOSTheme.muted, in: Capsule())
                }
                Spacer()
                if !task.codexThreads.isEmpty {
                    Label("\(task.codexThreads.count)", systemImage: "terminal")
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textSecondary)
                }
            }
        }
        .padding(AgentOSMetrics.itemSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .agentOSPanel(
            cornerRadius: AgentOSMetrics.radiusExtraLarge,
            background: isHovering && !isSelected ? AgentOSTheme.surfaceHover : AgentOSTheme.card,
            border: isSelected ? task.status.tint.opacity(0.9) : AgentOSTheme.border
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}
