import SwiftUI

struct SidebarView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selection: String

    var body: some View {
        List(selection: $selection) {
            Section("Agent OS") {
                sidebarRow(
                    title: "Focus",
                    detail: "Active, waiting, review",
                    image: "scope",
                    count: tasks.filter { [.active, .waiting, .review].contains($0.status) }.count
                )
                .tag("focus")

                sidebarRow(
                    title: "Board",
                    detail: "All unfinished outcomes",
                    image: "rectangle.3.group",
                    count: tasks.filter(\.status.isUnfinished).count
                )
                .tag("board")
            }

            Section("Projects") {
                ForEach(projects) { project in
                    sidebarRow(
                        title: project.displayName,
                        detail: project.key,
                        image: "folder",
                        count: tasks.filter { $0.projects.contains(project.key) && $0.status.isUnfinished }.count
                    )
                    .tag("project:\(project.key)")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Agent OS")
    }

    private func sidebarRow(title: String, detail: String, image: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(count, format: .number)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
