import SwiftUI

struct FocusView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?

    var body: some View {
        let rows = FocusDateSections.rows(from: tasks)

        List(selection: $selectedTaskID) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                switch row {
                case let .section(bucket):
                    FocusSectionHeaderView(
                        title: bucket.title,
                        topPadding: FocusListLayout.sectionTopPadding(
                            addsContentPadding: index == rows.startIndex
                        )
                    )
                    .modifier(FocusListRowStyle())
                case let .task(task):
                    FocusTaskRowView(projects: projects, task: task)
                        .tag(task.id)
                        .modifier(FocusListRowStyle())
                }
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
}

private struct FocusListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets())
            .listRowBackground(AgentOSTheme.canvas)
            .listRowSeparator(.hidden)
    }
}

private struct FocusTaskRowView: View {
    let projects: [AgentOSProject]
    let task: AgentOSTask

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: AgentOSTypography.listFlow) {
                attributionBadge(for: task)

                Text(task.title)
                    .font(AgentOSTypography.listTitle)
                    .foregroundStyle(AgentOSTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(task.nextAction)
                    .font(AgentOSTypography.listBody)
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .lineSpacing(AgentOSTypography.listBodyLineSpacing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: AgentOSMetrics.focusTextMeasure, alignment: .leading)

            Spacer(minLength: 24)

            StatusBadge(status: task.status)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, AgentOSMetrics.focusRowHorizontalPadding)
        .padding(.vertical, AgentOSMetrics.focusRowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? AgentOSTheme.surfaceHover : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AgentOSTheme.border)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onHover { newValue in
            if newValue != isHovering {
                isHovering = newValue
            }
        }
        .pointingHandCursor()
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

private struct FocusSectionHeaderView: View {
    let title: String
    let topPadding: CGFloat

    var body: some View {
        Text(title)
            .font(AgentOSTypography.listSectionTitle)
            .foregroundStyle(AgentOSTheme.textSecondary)
            .textCase(nil)
            .padding(.horizontal, AgentOSMetrics.focusRowHorizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, AgentOSMetrics.focusSectionHeaderBottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
