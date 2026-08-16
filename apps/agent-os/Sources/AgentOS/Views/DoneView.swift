import SwiftUI

struct DoneView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

    @State private var projectKey = "all"
    @State private var period: AgentOSCompletionPeriod = .all
    @State private var statusKey = "all"
    @State private var followUpKey = "all"
    private let now = Date()

    private var filteredTasks: [AgentOSTask] {
        tasks.filter { task in
            let matchesProject = projectKey == "all" || task.projects.contains(projectKey)
            let matchesPeriod = AgentOSDateMath.contains(task.completedAt, in: period, relativeTo: now)
            let matchesStatus = statusKey == "all" || task.status.rawValue == statusKey
            let matchesFollowUp = followUpKey == "all" || task.completionFollowUpStatus.rawValue == followUpKey
            return !task.status.isUnfinished && matchesProject && matchesPeriod && matchesStatus && matchesFollowUp
        }
        .sorted { $0.completedAt > $1.completedAt }
    }

    private var trackedSeconds: Int {
        filteredTasks.reduce(into: 0) { $0 += $1.activity.totalSeconds }
    }

    private var groupedTasks: [(title: String, tasks: [AgentOSTask])] {
        Dictionary(grouping: filteredTasks) { task -> String in
            guard let date = AgentOSDateMath.parse(task.completedAt) else { return "Unknown date" }
            return date.formatted(.dateTime.month(.wide).year())
        }
        .map { (title: $0.key, tasks: $0.value) }
        .sorted { ($0.tasks.first?.completedAt ?? "") > ($1.tasks.first?.completedAt ?? "") }
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: AgentOSMetrics.sectionSpacing) {
                overview
                filters
                completedOutcomes
            }
            .padding(AgentOSMetrics.contentPadding)
        }
        .background(AgentOSTheme.canvas)
        .navigationTitle("Done")
    }

    private var overview: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: AgentOSMetrics.itemSpacing)],
            spacing: AgentOSMetrics.itemSpacing
        ) {
            overviewCard(
                title: "Outcomes",
                value: filteredTasks.count.formatted(),
                detail: "Outcomes in this view",
                systemImage: "checkmark.circle"
            )
            overviewCard(
                title: "Tracked time",
                value: AgentOSTimeFormatter.compact(seconds: trackedSeconds),
                detail: "Exact-linked outcome work",
                systemImage: "clock"
            )
            overviewCard(
                title: "Needs follow-up",
                value: filteredTasks.filter { $0.status == .done && $0.completionFollowUpStatus == .pending }.count.formatted(),
                detail: "Completion messages still pending",
                systemImage: "bubble.left.and.exclamationmark.bubble.right"
            )
        }
    }

    private func overviewCard(title: String, value: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(AgentOSTheme.textSecondary)
                Spacer()
                Image(systemName: systemImage).foregroundStyle(AgentOSTheme.textTertiary)
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AgentOSTheme.textPrimary)
            Text(detail).font(.caption).foregroundStyle(AgentOSTheme.textTertiary)
        }
        .padding(AgentOSMetrics.itemSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .agentOSPanel(background: AgentOSTheme.card)
    }

    private var filters: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { projectControl; periodControl; statusControl; followUpControl }
            VStack(alignment: .leading, spacing: 12) { projectControl; periodControl; statusControl; followUpControl }
        }
    }

    private var projectControl: some View {
        AgentOSSelect(
            label: "Project",
            systemImage: "folder",
            iconColor: AgentOSTheme.textSecondary,
            selectedID: projectKey,
            selectedTitle: projectKey == "all" ? "All projects" : (projects.first { $0.key == projectKey }?.displayName ?? projectKey),
            selectedColor: AgentOSTheme.textPrimary,
            options: [AgentOSSelectOption(id: "all", title: "All projects", systemImage: "square.grid.2x2")]
                + projects.map { AgentOSSelectOption(id: $0.key, title: $0.displayName, systemImage: "folder") },
            onSelect: { projectKey = $0 }
        )
        .frame(minWidth: 210)
    }

    private var periodControl: some View {
        AgentOSSelect(
            label: "Period",
            systemImage: "calendar",
            iconColor: AgentOSTheme.textSecondary,
            selectedID: period.id,
            selectedTitle: period.displayName,
            selectedColor: AgentOSTheme.textPrimary,
            options: AgentOSCompletionPeriod.allCases.map {
                AgentOSSelectOption(id: $0.id, title: $0.displayName, systemImage: periodImage($0))
            },
            onSelect: { selectedID in
                guard let selectedPeriod = AgentOSCompletionPeriod(rawValue: selectedID) else { return }
                period = selectedPeriod
            }
        )
        .frame(minWidth: 180)
    }

    private var statusControl: some View {
        AgentOSSelect(
            label: "Lifecycle",
            systemImage: "checkmark.circle",
            iconColor: AgentOSTheme.textSecondary,
            selectedID: statusKey,
            selectedTitle: statusKey == "all" ? "Done & cancelled" : (TaskStatus(rawValue: statusKey)?.displayName ?? statusKey),
            selectedColor: TaskStatus(rawValue: statusKey)?.tint ?? AgentOSTheme.textPrimary,
            options: [AgentOSSelectOption(id: "all", title: "Done & cancelled", systemImage: "archivebox")]
                + [TaskStatus.done, .cancelled].map {
                    AgentOSSelectOption(id: $0.rawValue, title: $0.displayName, systemImage: $0.systemImage, tint: $0.tint)
                },
            onSelect: { statusKey = $0 }
        )
        .frame(minWidth: 210)
    }

    private var followUpControl: some View {
        AgentOSSelect(
            label: "Follow-up",
            systemImage: "bubble.left.and.bubble.right",
            iconColor: AgentOSTheme.textSecondary,
            selectedID: followUpKey,
            selectedTitle: followUpKey == "all"
                ? "All follow-up states"
                : (AgentOSCompletionFollowUpStatus(rawValue: followUpKey)?.displayName ?? followUpKey),
            selectedColor: followUpColor(AgentOSCompletionFollowUpStatus(rawValue: followUpKey)),
            options: [AgentOSSelectOption(id: "all", title: "All follow-up states", systemImage: "line.3.horizontal.decrease.circle")]
                + AgentOSCompletionFollowUpStatus.allCases.map {
                    AgentOSSelectOption(id: $0.rawValue, title: $0.displayName, systemImage: followUpImage($0), tint: followUpColor($0))
                },
            onSelect: { followUpKey = $0 }
        )
        .frame(minWidth: 220)
    }

    private var completedOutcomes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed outcomes").font(.headline).foregroundStyle(AgentOSTheme.textPrimary)
                Spacer()
                Text("\(filteredTasks.count) records").font(.caption).foregroundStyle(AgentOSTheme.textTertiary)
            }

            if groupedTasks.isEmpty {
                ContentUnavailableView(
                    "No completed outcomes",
                    systemImage: "checkmark.circle",
                    description: Text("Done outcomes remain here with their time, PRs, source threads, and completion follow-up state.")
                )
                .foregroundStyle(AgentOSTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 240)
                .agentOSPanel(background: AgentOSTheme.card)
            } else {
                ForEach(groupedTasks, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AgentOSTheme.textSecondary)
                            .textCase(.uppercase)
                        VStack(spacing: 0) {
                            ForEach(Array(group.tasks.enumerated()), id: \.element.id) { index, task in
                                doneRow(task)
                                if index < group.tasks.count - 1 { Divider().overlay(AgentOSTheme.border) }
                            }
                        }
                        .agentOSPanel(background: AgentOSTheme.card)
                    }
                }
            }
        }
    }

    private func doneRow(_ task: AgentOSTask) -> some View {
        Button { selectedTaskID = task.id } label: {
            HStack(alignment: .top, spacing: 14) {
                StatusBadge(status: task.status, compact: true).padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AgentOSTheme.textPrimary)
                        .lineLimit(1)
                    Text(task.summary)
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(projectLabel(for: task), systemImage: "folder")
                        if !task.sources.pullRequests.isEmpty {
                            Label("\(task.sources.pullRequests.count) PR", systemImage: "arrow.triangle.pull")
                        }
                        if !task.sources.slackThreads.isEmpty {
                            Label("\(task.sources.slackThreads.count) Slack", systemImage: "bubble.left.and.bubble.right")
                        }
                        if !task.codexThreads.isEmpty { Label("\(task.codexThreads.count)", systemImage: "terminal") }
                    }
                    .font(.caption)
                    .foregroundStyle(AgentOSTheme.textTertiary)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 7) {
                    followUpBadge(task.completionFollowUpStatus)
                    Label(AgentOSTimeFormatter.compact(seconds: task.activity.totalSeconds), systemImage: "clock")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(AgentOSTheme.textSecondary)
                    Text(formattedDate(task.completedAt)).font(.caption).foregroundStyle(AgentOSTheme.textTertiary)
                }
            }
            .padding(AgentOSMetrics.itemSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .accessibilityHint("Open completed outcome details")
    }

    private func followUpBadge(_ status: AgentOSCompletionFollowUpStatus) -> some View {
        Label(status.displayName, systemImage: followUpImage(status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(followUpColor(status))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(followUpColor(status).opacity(0.10), in: Capsule())
            .overlay { Capsule().stroke(followUpColor(status).opacity(0.35), lineWidth: 1) }
    }

    private func followUpImage(_ status: AgentOSCompletionFollowUpStatus) -> String {
        switch status {
        case .pending: "bubble.left.and.exclamationmark.bubble.right"
        case .sent: "paperplane"
        case .notRequired: "minus.circle"
        }
    }

    private func followUpColor(_ status: AgentOSCompletionFollowUpStatus?) -> Color {
        switch status {
        case .pending: AgentOSTheme.warning
        case .sent: TaskStatus.active.tint
        case .notRequired, nil: AgentOSTheme.textSecondary
        }
    }

    private func projectLabel(for task: AgentOSTask) -> String {
        guard !task.projects.isEmpty else { return "Unassigned" }
        return task.projects.map { key in projects.first { $0.key == key }?.displayName ?? key }.joined(separator: ", ")
    }

    private func formattedDate(_ value: String) -> String {
        guard let date = AgentOSDateMath.parse(value) else { return value }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func periodImage(_ period: AgentOSCompletionPeriod) -> String {
        switch period {
        case .today: "sun.max"
        case .sevenDays: "calendar.badge.clock"
        case .thirtyDays: "calendar"
        case .all: "infinity"
        }
    }
}
