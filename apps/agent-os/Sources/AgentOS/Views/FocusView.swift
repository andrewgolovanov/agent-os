import SwiftUI

struct FocusView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?
    @State private var hoveredTaskID: String?

    var body: some View {
        List(selection: $selectedTaskID) {
            ForEach(tasks) { task in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(task.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(AgentOSTheme.textPrimary)
                                .lineLimit(1)

                            attributionBadge(for: task)
                        }

                        Text(task.nextAction)
                            .font(.callout)
                            .foregroundStyle(AgentOSTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusBadge(status: task.status)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    hoveredTaskID == task.id ? AgentOSTheme.surfaceHover : Color.clear,
                    in: RoundedRectangle(
                        cornerRadius: AgentOSMetrics.radiusMedium,
                        style: .continuous
                    )
                )
                .contentShape(Rectangle())
                .onHover { isHovering in
                    if isHovering {
                        hoveredTaskID = task.id
                    } else if hoveredTaskID == task.id {
                        hoveredTaskID = nil
                    }
                }
                .pointingHandCursor()
                .animation(.easeOut(duration: 0.12), value: hoveredTaskID == task.id)
                .tag(task.id)
                .listRowBackground(AgentOSTheme.canvas)
                .listRowSeparatorTint(AgentOSTheme.border)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AgentOSTheme.canvas)
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView("Nothing needs attention", systemImage: "checkmark.circle")
                    .foregroundStyle(AgentOSTheme.textSecondary)
            }
        }
        .navigationTitle("Focus")
    }

    private func attributionBadge(for task: AgentOSTask) -> some View {
        let attribution = attributionLabel(for: task)

        return Label(attribution.label, systemImage: attribution.image)
            .font(.caption)
            .foregroundStyle(AgentOSTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AgentOSTheme.muted, in: Capsule())
            .fixedSize()
            .help(attribution.label)
            .accessibilityLabel("Work context: \(attribution.label)")
    }

    private func attributionLabel(for task: AgentOSTask) -> (label: String, image: String) {
        if task.projects.isEmpty, let label = task.labels.first {
            return (label.name, "bubble.left.and.bubble.right")
        }
        guard !task.projects.isEmpty else { return ("Unassigned", "tray") }

        let label = task.projects.map { key in
            projects.first { $0.key == key }?.displayName ?? key
        }
        .joined(separator: ", ")
        return (label, "folder")
    }
}
