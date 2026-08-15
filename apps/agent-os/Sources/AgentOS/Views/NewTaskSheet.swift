import SwiftUI

struct NewTaskSheet: View {
    let store: AgentOSStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var project = ""
    @State private var goal = ""
    @State private var nextAction = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: AgentOSMetrics.itemSpacing) {
            Text("New Agent OS outcome")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AgentOSTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                themedField("Title", text: $title)

                AgentOSSelect(
                    label: "Project",
                    systemImage: "folder",
                    iconColor: AgentOSTheme.textSecondary,
                    selectedID: project,
                    selectedTitle: selectedProjectName,
                    selectedColor: AgentOSTheme.textSecondary,
                    options: projectOptions,
                    onSelect: { project = $0 }
                )

                TextField("Goal", text: $goal, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .agentOSMultilineInputChrome(minHeight: 72)

                TextField("Next action", text: $nextAction, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .agentOSMultilineInputChrome(minHeight: 72)
            }

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AgentOSTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: AgentOSMetrics.controlHeight)
                        .background(
                            AgentOSTheme.inputSurface,
                            in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                                .stroke(AgentOSTheme.input, lineWidth: 1)
                        }
                }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                Button {
                    isSaving = true
                    Task {
                        let created = await store.createTask(
                            title: title,
                            project: project.isEmpty ? nil : project,
                            goal: goal,
                            nextAction: nextAction
                        )
                        isSaving = false
                        if created { dismiss() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Create")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(canCreate ? AgentOSTheme.primaryForeground : AgentOSTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .frame(height: AgentOSMetrics.controlHeight)
                    .background(
                        canCreate ? AgentOSTheme.primary : AgentOSTheme.muted,
                        in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
        }
        .padding(AgentOSMetrics.contentPadding)
        .frame(width: 480)
        .background(AgentOSTheme.canvas)
    }

    private func themedField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .agentOSInputChrome()
    }

    private var selectedProjectName: String {
        store.projects.first { $0.key == project }?.displayName ?? "Unassigned"
    }

    private var projectOptions: [AgentOSSelectOption<String>] {
        [
            AgentOSSelectOption(
                id: "",
                title: "Unassigned",
                systemImage: "tray",
                tint: AgentOSTheme.textSecondary
            )
        ] + store.projects.map {
            AgentOSSelectOption(
                id: $0.key,
                title: $0.displayName,
                systemImage: "folder",
                tint: AgentOSTheme.textSecondary
            )
        }
    }

    private var canCreate: Bool {
        !isSaving && !title.isEmpty && !goal.isEmpty && !nextAction.isEmpty
    }
}
