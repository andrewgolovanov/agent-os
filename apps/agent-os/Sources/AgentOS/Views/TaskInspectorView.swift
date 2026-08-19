import SwiftUI

struct TaskInspectorView: View {
    let task: AgentOSTask
    let isBusy: Bool
    let sourceMetadata: [String: AgentOSSourceMetadata]
    let loadingSourceIDs: Set<String>
    let onClose: () -> Void
    let onStatusChange: (TaskStatus) -> Void
    let onCompletionFollowUpChange: (AgentOSCompletionFollowUpStatus) -> Void
    let onCopyCompletionUpdate: () -> Void
    let onOpenNewCodex: () -> Void
    let onOpenCodex: (String) -> Void
    @State private var isCloseHovering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                inspectorHeader
                    .padding(.bottom, AgentOSMetrics.sectionSpacing)

                Divider().overlay(AgentOSTheme.border)

                inspectorSection("Goal", text: task.goal)
                sectionDivider
                inspectorSection("Current state", text: task.summary)
                sectionDivider
                inspectorSection("Next action", text: task.nextAction)

                if let waitingOn = task.waitingOn {
                    sectionDivider
                    waitingSection(waitingOn)
                }

                sectionDivider
                actionsSection

                if !task.codexThreads.isEmpty {
                    sectionDivider
                    codexSection
                }

                if !task.sources.supportingItems.isEmpty {
                    sectionDivider
                    sourcesSection
                }
            }
            .padding(.horizontal, AgentOSMetrics.contentPadding)
            .padding(.vertical, AgentOSMetrics.contentPadding)
        }
        .background(AgentOSTheme.canvas)
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(task.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AgentOSTheme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.callout.weight(.medium))
                        .frame(width: AgentOSMetrics.compactControlHeight, height: AgentOSMetrics.compactControlHeight)
                        .background(
                            isCloseHovering ? AgentOSTheme.interactiveAccent : Color.clear,
                            in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(AgentOSTheme.textSecondary)
                .onHover { isCloseHovering = $0 }
                .pointingHandCursor()
                .keyboardShortcut(.cancelAction)
                .help("Close task details")
                .accessibilityLabel("Close task details")
            }

            HStack(spacing: 12) {
                StatusBadge(status: task.status)

                if !task.projects.isEmpty {
                    Label(task.projects.joined(separator: ", "), systemImage: "folder")
                        .lineLimit(1)
                        .help(task.projects.joined(separator: ", "))
                }

                if !task.labels.isEmpty {
                    let labelNames = task.labels.map(\.name).joined(separator: ", ")
                    Label(labelNames, systemImage: "bubble.left.and.bubble.right")
                        .lineLimit(1)
                        .help(labelNames)
                }

                Spacer(minLength: 8)

                Label(AgentOSTimeFormatter.compact(seconds: task.activity.totalSeconds), systemImage: "clock")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .fixedSize()
            }
            .font(.caption)
            .foregroundStyle(AgentOSTheme.textSecondary)

            if !task.sources.pullRequestItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle(task.sources.pullRequestItems.count == 1 ? "Pull request" : "Pull requests")

                    ForEach(task.sources.pullRequestItems) { item in
                        sourceRow(for: item)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var sectionDivider: some View {
        Divider().overlay(AgentOSTheme.border)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Actions")

            AgentOSSelect(
                label: "Lifecycle status",
                systemImage: task.status.systemImage,
                iconColor: task.status.tint,
                selectedID: task.status,
                selectedTitle: task.status.displayName,
                selectedColor: task.status.tint,
                options: TaskStatus.allCases.map {
                    AgentOSSelectOption(
                        id: $0,
                        title: $0.displayName,
                        systemImage: $0.systemImage,
                        tint: $0.tint
                    )
                },
                isDisabled: isBusy,
                onSelect: onStatusChange
            )

            if task.status == .done {
                AgentOSSelect(
                    label: "Completion follow-up",
                    systemImage: followUpImage(task.completionFollowUpStatus),
                    iconColor: followUpColor(task.completionFollowUpStatus),
                    selectedID: task.completionFollowUpStatus,
                    selectedTitle: task.completionFollowUpStatus.displayName,
                    selectedColor: followUpColor(task.completionFollowUpStatus),
                    options: AgentOSCompletionFollowUpStatus.allCases.map {
                        AgentOSSelectOption(
                            id: $0,
                            title: $0.displayName,
                            systemImage: followUpImage($0),
                            tint: followUpColor($0)
                        )
                    },
                    isDisabled: isBusy,
                    onSelect: onCompletionFollowUpChange
                )

                InspectorActionRow(
                    title: "Copy completion update",
                    detail: "Summary and pull request links",
                    systemImage: "doc.on.doc",
                    trailingSystemImage: "doc.on.doc",
                    action: onCopyCompletionUpdate
                )

                Text("Paste the update into the relevant Slack thread, then mark follow-up as Sent. Agent OS does not send messages automatically.")
                    .font(.caption)
                    .foregroundStyle(AgentOSTheme.textTertiary)
            }

            PrimaryInspectorButton(
                title: "Open new Codex task",
                systemImage: "arrow.up.forward.app",
                isBusy: isBusy,
                action: onOpenNewCodex
            )
            .disabled(isBusy || task.projects.count != 1)

            Text("Creates the task in its registered project and copies the prepared prompt.")
                .font(.caption)
                .foregroundStyle(AgentOSTheme.textTertiary)
        }
        .padding(.vertical, AgentOSMetrics.sectionSpacing)
    }

    private var codexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Codex tasks")

            ForEach(task.codexThreads) { membership in
                InspectorActionRow(
                    title: membership.title ?? membership.role,
                    detail: membership.status,
                    systemImage: "terminal",
                    action: { onOpenCodex(membership.threadID) }
                )
            }
        }
        .padding(.vertical, AgentOSMetrics.sectionSpacing)
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Sources")

            ForEach(task.sources.supportingItems) { item in
                sourceRow(for: item)
            }
        }
        .padding(.vertical, AgentOSMetrics.sectionSpacing)
    }

    @ViewBuilder
    private func sourceRow(for item: AgentOSSourceItem) -> some View {
        if let url = URL(string: item.link.url) {
            SourceLinkRow(
                url: url,
                kind: item.kind,
                metadata: sourceMetadata[item.id] ?? AgentOSSourcePresentation.localMetadata(for: item),
                isLoading: loadingSourceIDs.contains(item.id)
            )
        }
    }

    private func inspectorSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            Text(text.isEmpty ? "—" : text)
                .font(.body)
                .foregroundStyle(text.isEmpty ? AgentOSTheme.textTertiary : AgentOSTheme.textPrimary)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, AgentOSMetrics.sectionSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func waitingSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1)
                .fill(TaskStatus.waiting.tint)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Waiting on", color: TaskStatus.waiting.tint)
                Text(text)
                    .font(.body)
                    .foregroundStyle(AgentOSTheme.textPrimary)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AgentOSMetrics.sectionSpacing)
        .padding(.horizontal, 12)
        .background(TaskStatus.waiting.tint.opacity(0.055), in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous))
    }

    private func sectionTitle(_ title: String, color: Color = AgentOSTheme.textSecondary) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(0.45)
    }

    private func followUpImage(_ status: AgentOSCompletionFollowUpStatus) -> String {
        switch status {
        case .pending: "bubble.left.and.exclamationmark.bubble.right"
        case .sent: "paperplane"
        case .notRequired: "minus.circle"
        }
    }

    private func followUpColor(_ status: AgentOSCompletionFollowUpStatus) -> Color {
        switch status {
        case .pending: AgentOSTheme.warning
        case .sent: TaskStatus.active.tint
        case .notRequired: AgentOSTheme.textSecondary
        }
    }

}

private struct PrimaryInspectorButton: View {
    let title: String
    let systemImage: String
    let isBusy: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundStyle(isEnabled ? AgentOSTheme.accentForeground : AgentOSTheme.textTertiary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: AgentOSMetrics.controlHeight)
            .background(
                isEnabled ? (isHovering ? AgentOSTheme.primary.opacity(0.90) : AgentOSTheme.primary) : AgentOSTheme.muted,
                in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                    .stroke(isEnabled ? Color.clear : AgentOSTheme.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct InspectorActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    var trailingSystemImage = "arrow.up.forward.app"
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AgentOSTheme.textPrimary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textTertiary)
                }
                Spacer()
                Image(systemName: trailingSystemImage)
                    .font(.caption)
                    .foregroundStyle(AgentOSTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(isHovering ? AgentOSTheme.surfaceHover : AgentOSTheme.surface, in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                    .stroke(isHovering ? AgentOSTheme.input : AgentOSTheme.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .pointingHandCursor()
    }
}

private struct SourceLinkRow: View {
    let url: URL
    let kind: AgentOSSourceKind
    let metadata: AgentOSSourceMetadata
    let isLoading: Bool

    @State private var isHovering = false

    var body: some View {
        Link(destination: url) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(iconColor)
                    .frame(width: 18, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(metadata.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AgentOSTheme.textPrimary)
                        .lineLimit(2)

                    Text(metadata.context)
                        .font(.caption)
                        .foregroundStyle(AgentOSTheme.textSecondary)
                        .lineLimit(2)

                    if let secondaryStatus = metadata.secondaryStatus {
                        Text(secondaryStatus)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(secondaryStatusColor)
                    }
                }

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 22)
                } else if let status = metadata.status {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.11), in: Capsule())
                        .overlay {
                            Capsule().stroke(statusColor.opacity(0.32), lineWidth: 1)
                        }
                }

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isHovering ? AgentOSTheme.textPrimary : AgentOSTheme.textTertiary)
                    .frame(height: 22)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? AgentOSTheme.surfaceHover : AgentOSTheme.surface, in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                    .stroke(isHovering ? AgentOSTheme.input : AgentOSTheme.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .pointingHandCursor()
        .help("Open \(url.absoluteString)")
        .accessibilityHint("Opens the source in its default app")
    }

    private var systemImage: String {
        switch kind {
        case .slackThread: "bubble.left.and.bubble.right"
        case .pullRequest: "arrow.triangle.pull"
        case .figma: "paintpalette"
        case .deployment: "globe"
        case .other: "link"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .slackThread: AgentOSTheme.information
        case .pullRequest: AgentOSTheme.textPrimary
        case .figma: TaskStatus.planned.tint
        case .deployment: TaskStatus.active.tint
        case .other: AgentOSTheme.textSecondary
        }
    }

    private var statusColor: Color {
        color(for: metadata.statusTone)
    }

    private var secondaryStatusColor: Color {
        color(for: metadata.secondaryStatusTone ?? metadata.statusTone)
    }

    private func color(for tone: AgentOSSourceStatusTone) -> Color {
        switch tone {
        case .positive: TaskStatus.active.tint
        case .merged: TaskStatus.planned.tint
        case .warning: TaskStatus.waiting.tint
        case .neutral: AgentOSTheme.textSecondary
        case .negative: TaskStatus.cancelled.tint
        case .information: TaskStatus.review.tint
        }
    }
}
