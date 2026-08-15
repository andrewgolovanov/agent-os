import SwiftUI

struct FocusView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

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

                            projectBadge(for: task)
                        }

                        Text(task.nextAction)
                            .font(.callout)
                            .foregroundStyle(AgentOSTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusBadge(status: task.status)
                }
                .padding(.vertical, 7)
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

    private func projectBadge(for task: AgentOSTask) -> some View {
        let label = projectLabel(for: task)

        return Label(label, systemImage: "folder")
            .font(.caption)
            .foregroundStyle(AgentOSTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AgentOSTheme.muted, in: Capsule())
            .fixedSize()
            .help(label)
            .accessibilityLabel("Project: \(label)")
    }

    private func projectLabel(for task: AgentOSTask) -> String {
        guard !task.projects.isEmpty else { return "Unassigned" }

        return task.projects.map { key in
            projects.first { $0.key == key }?.displayName ?? key
        }
        .joined(separator: ", ")
    }
}
