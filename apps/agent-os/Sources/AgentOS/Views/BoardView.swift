import SwiftUI

struct BoardView: View {
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: AgentOSMetrics.itemSpacing) {
                ForEach(TaskStatus.boardColumns) { status in
                    boardColumn(status)
                }
            }
            .padding(AgentOSMetrics.contentPadding)
        }
        .background(AgentOSTheme.canvas)
        .navigationTitle("Board")
    }

    private func boardColumn(_ status: TaskStatus) -> some View {
        let columnTasks = tasks.filter { $0.status == status }
        return VStack(alignment: .leading, spacing: AgentOSMetrics.itemSpacing) {
            HStack {
                StatusBadge(status: status)
                Spacer()
                Text(columnTasks.count, format: .number)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, 2)
                    .background(AgentOSTheme.muted, in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusSmall))
            }

            if columnTasks.isEmpty {
                VStack(spacing: AgentOSMetrics.grid * 2) {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(status.tint.opacity(0.7))
                    Text("No \(status.displayName.lowercased()) tasks")
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 144)
                .accessibilityElement(children: .combine)
            } else {
                ForEach(columnTasks) { task in
                    Button {
                        selectedTaskID = task.id
                    } label: {
                        TaskCardView(task: task, isSelected: selectedTaskID == task.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AgentOSMetrics.itemSpacing)
        .frame(width: 320, alignment: .top)
        .agentOSPanel(
            cornerRadius: AgentOSMetrics.radiusExtraLarge,
            background: AgentOSTheme.background
        )
    }
}
