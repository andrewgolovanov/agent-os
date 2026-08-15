import SwiftUI

struct TaskInspectorView: View {
    let task: AgentOSTask?
    let isBusy: Bool
    let onStatusChange: (TaskStatus) -> Void
    let onOpenNewCodex: () -> Void
    let onOpenCodex: (String) -> Void

    var body: some View {
        if let task {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        Label(task.status.displayName, systemImage: task.status.systemImage)
                            .foregroundStyle(task.status.tint)
                    }

                    inspectorSection("Goal", text: task.goal)
                    inspectorSection("Current state", text: task.summary)
                    inspectorSection("Next action", text: task.nextAction)

                    if let waitingOn = task.waitingOn {
                        inspectorSection("Waiting on", text: waitingOn)
                    }

                    if !task.projects.isEmpty {
                        LabeledContent("Projects", value: task.projects.joined(separator: ", "))
                    }
                    LabeledContent("Tracked task time", value: duration(task.activity.totalSeconds))

                    Divider()
                    Menu("Set lifecycle status", systemImage: "arrow.triangle.2.circlepath") {
                        ForEach(TaskStatus.allCases) { status in
                            Button(status.displayName) { onStatusChange(status) }
                                .disabled(status == task.status)
                        }
                    }
                    .disabled(isBusy)

                    Button("Open new Codex task", systemImage: "arrow.up.forward.app", action: onOpenNewCodex)
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy || task.projects.count != 1)
                    Text("Creates the task in its registered project and copies the prepared prompt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !task.codexThreads.isEmpty {
                        Divider()
                        Text("Codex tasks")
                            .font(.headline)
                        ForEach(task.codexThreads.filter { $0.status != "archived" }) { membership in
                            Button {
                                onOpenCodex(membership.threadID)
                            } label: {
                                HStack {
                                    Image(systemName: "terminal")
                                    VStack(alignment: .leading) {
                                        Text(membership.title ?? membership.role)
                                            .lineLimit(1)
                                        Text(membership.status)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !task.sources.all.isEmpty {
                        Divider()
                        Text("Sources")
                            .font(.headline)
                        ForEach(task.sources.all) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    Label(sourceLabel(source), systemImage: "link")
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView("Select a task", systemImage: "sidebar.right")
        }
    }

    private func inspectorSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(text.isEmpty ? "—" : text)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    private func duration(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func sourceLabel(_ source: AgentOSSourceLink) -> String {
        URL(string: source.url)?.host() ?? source.identity
    }
}
