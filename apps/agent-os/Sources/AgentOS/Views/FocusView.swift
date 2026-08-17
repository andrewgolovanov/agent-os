import SwiftUI

struct FocusView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selectedTaskID: String?
    @State private var hoveredTaskID: String?

    var body: some View {
        List(selection: $selectedTaskID) {
            ForEach(FocusDateSections.rows(from: tasks)) { row in
                switch row {
                case let .section(bucket):
                    sectionHeader(bucket.title)
                case let .task(task):
                    taskRow(task)
                }
            }
        }
        .contentMargins(.top, AgentOSMetrics.focusContentTopPadding, for: .scrollContent)
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

    private func taskRow(_ task: AgentOSTask) -> some View {
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
        .background(hoveredTaskID == task.id ? AgentOSTheme.surfaceHover : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AgentOSTheme.border)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
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
        .listRowInsets(EdgeInsets())
        .listRowBackground(AgentOSTheme.canvas)
        .listRowSeparator(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AgentOSTypography.listSectionTitle)
            .foregroundStyle(AgentOSTheme.textSecondary)
            .textCase(nil)
            .padding(.horizontal, AgentOSMetrics.focusRowHorizontalPadding)
            .padding(.top, AgentOSMetrics.focusSectionHeaderTopPadding)
            .padding(.bottom, AgentOSMetrics.focusSectionHeaderBottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets())
            .listRowBackground(AgentOSTheme.canvas)
            .listRowSeparator(.hidden)
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
