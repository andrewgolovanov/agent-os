import SwiftUI

struct SidebarView: View {
    let projects: [AgentOSProject]
    let tasks: [AgentOSTask]
    @Binding var selection: String
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
                }

                sidebarSection("Projects") {
                    ForEach(projects) { project in
                        sidebarRow(
                            key: "project:\(project.key)",
                            title: project.displayName,
                            detail: project.key,
                            image: "folder",
                            count: tasks.filter { $0.projects.contains(project.key) && $0.status.isUnfinished }.count
                        )
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

    private func sidebarRow(key: String, title: String, detail: String, image: String, count: Int) -> some View {
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
                Text(count, format: .number)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(AgentOSTheme.textSecondary)
                    .frame(minWidth: 20, minHeight: 20)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: 48, alignment: .top)
            .frame(maxWidth: .infinity)
            .background(
                selection == key || hoveredKey == key ? AgentOSTheme.sidebarAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
