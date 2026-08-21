import SwiftUI

struct SidebarView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    let pinnedProjectKeys: [String]
    @Binding var selection: String
    let onToggleProjectPin: (String) -> Void
    @State private var hoveredKey: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sidebarSection("Agent OS") {
                    sidebarRow(
                        key: "focus",
                        title: "Focus",
                        detail: "Active, waiting, review",
                        image: "scope",
                        count: tasks.filter { [.active, .waiting, .review].contains($0.status) }.count
                    )

                    sidebarRow(
                        key: "board",
                        title: "Board",
                        detail: "All unfinished outcomes",
                        image: "rectangle.3.group",
                        count: tasks.filter(\.status.isUnfinished).count
                    )

                    sidebarRow(
                        key: "done",
                        title: "Done",
                        detail: "Completed work, time, follow-up",
                        image: "checkmark.circle",
                        count: tasks.filter { !$0.status.isUnfinished }.count
                    )
                }

                if !pinnedProjects.isEmpty {
                    sidebarSection("Pinned") {
                        ForEach(pinnedProjects) { project in
                            projectRow(project, isPinned: true)
                        }
                    }
                }

                if !unpinnedProjects.isEmpty {
                    sidebarSection("Projects") {
                        ForEach(unpinnedProjects) { project in
                            projectRow(project, isPinned: false)
                        }
                    }
                }

                if !labels.isEmpty {
                    sidebarSection("Labels") {
                        ForEach(labels) { label in
                            sidebarRow(
                                key: "label:\(label.key)",
                                title: label.name,
                                detail: "Slack channel",
                                image: "bubble.left.and.bubble.right",
                                count: tasks.filter { task in
                                    task.labels.contains { $0.key == label.key } && task.status.isUnfinished
                                }.count
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background {
            AgentOSTheme.sidebar
                .ignoresSafeArea(.container, edges: [.top, .bottom])
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: SidebarWidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .navigationTitle("Agent OS")
    }

    private var labels: [AgentOSLabel] {
        Self.visibleLabels(projects: projects, tasks: tasks)
    }

    private var pinnedProjects: [AgentOSProject] {
        Self.pinnedProjects(projects: projects, pinnedProjectKeys: pinnedProjectKeys)
    }

    private var unpinnedProjects: [AgentOSProject] {
        Self.unpinnedProjects(
            projects: projects,
            pinnedProjectKeys: pinnedProjectKeys,
            tasks: tasks
        )
    }

    nonisolated static func pinnedProjects(
        projects: [AgentOSProject],
        pinnedProjectKeys: [String]
    ) -> [AgentOSProject] {
        let projectsByKey = Dictionary(uniqueKeysWithValues: projects.map { ($0.key, $0) })
        return pinnedProjectKeys.compactMap { projectsByKey[$0] }
    }

    nonisolated static func unpinnedProjects(
        projects: [AgentOSProject],
        pinnedProjectKeys: [String],
        tasks: [AgentOSTask]
    ) -> [AgentOSProject] {
        let pinnedKeys = Set(pinnedProjectKeys)
        let activeProjectKeys = Set(
            tasks
                .filter(\.status.isUnfinished)
                .flatMap(\.projects)
        )
        return projects.filter {
            !pinnedKeys.contains($0.key) && activeProjectKeys.contains($0.key)
        }
    }

    nonisolated static func visibleLabels(projects: [AgentOSProject], tasks: [AgentOSTask]) -> [AgentOSLabel] {
        visibleLabels(
            projects: projects,
            labels: tasks.flatMap(\.labels)
        )
    }

    nonisolated static func visibleLabels(projects: [AgentOSProject], labels: [AgentOSLabel]) -> [AgentOSLabel] {
        var seen = Set<String>()
        let mappedLabelKeys = Set(projects.flatMap(\.slackChannels).map(\.labelKey))
        return labels
            .filter { !mappedLabelKeys.contains($0.key) }
            .filter { seen.insert($0.key).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AgentOSTheme.textSecondary)
                .padding(.horizontal, 8)
                .frame(height: 32, alignment: .leading)

            content()
        }
    }

    private func projectRow(_ project: AgentOSProject, isPinned: Bool) -> some View {
        sidebarRow(
            key: "project:\(project.key)",
            title: project.displayName,
            detail: project.key,
            image: "folder",
            count: tasks.filter { $0.projects.contains(project.key) && $0.status.isUnfinished }.count,
            isPinned: isPinned,
            onTogglePin: { onToggleProjectPin(project.key) }
        )
        .contextMenu {
            Button(isPinned ? "Unpin Project" : "Pin Project", systemImage: isPinned ? "star.slash" : "star") {
                onToggleProjectPin(project.key)
            }
        }
    }

    private func sidebarRow(
        key: String,
        title: String,
        detail: String,
        image: String,
        count: Int,
        isPinned: Bool? = nil,
        onTogglePin: (() -> Void)? = nil
    ) -> some View {
        ZStack(alignment: .trailing) {
            Button {
                selection = key
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: image)
                        .font(.callout)
                        .foregroundStyle(selection == key ? AgentOSTheme.sidebarAccentForeground : AgentOSTheme.textSecondary)
                        .frame(width: 18, height: 20, alignment: .top)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.callout.weight(selection == key ? .medium : .regular))
                            .foregroundStyle(AgentOSTheme.sidebarForeground)
                            .lineLimit(1)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(AgentOSTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        if onTogglePin != nil {
                            Color.clear
                                .frame(width: 24, height: 20)
                        }
                        Text(count, format: .number)
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(AgentOSTheme.textSecondary)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .frame(height: 48, alignment: .top)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let isPinned, let onTogglePin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textSecondary)
                        .frame(width: 24, height: 20)
                        .padding(.top, 6)
                        .padding(.bottom, 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 32)
                .opacity(isPinned || hoveredKey == key ? 1 : 0)
                .allowsHitTesting(isPinned || hoveredKey == key)
                .accessibilityLabel(isPinned ? "Unpin \(title)" : "Pin \(title)")
                .help(isPinned ? "Unpin \(title)" : "Pin \(title)")
            }
        }
        .frame(height: 48, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            selection == key || hoveredKey == key ? AgentOSTheme.sidebarAccent : Color.clear,
            in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium)
        )
        .onHover { isHovering in
            hoveredKey = isHovering ? key : (hoveredKey == key ? nil : hoveredKey)
        }
        .pointingHandCursor()
    }
}

struct SidebarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = AgentOSMetrics.sidebarWidth

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
