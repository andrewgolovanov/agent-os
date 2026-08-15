import SwiftUI

struct AgentOSSelectOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let systemImage: String?
    let tint: Color

    init(id: ID, title: String, systemImage: String? = nil, tint: Color = AgentOSTheme.textPrimary) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }
}

struct AgentOSSelect<ID: Hashable>: View {
    let label: String
    let systemImage: String
    let iconColor: Color
    let selectedID: ID
    let selectedTitle: String
    let selectedColor: Color
    let options: [AgentOSSelectOption<ID>]
    var isDisabled = false
    let onSelect: (ID) -> Void

    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var hoveredOptionID: ID?
    @State private var triggerWidth: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard !isDisabled else { return }
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.callout)
                        .foregroundStyle(iconColor)
                        .frame(width: 18, height: 20)

                    Text(label)
                        .font(.callout)
                        .foregroundStyle(AgentOSTheme.textPrimary)

                    Spacer(minLength: 8)

                    Text(selectedTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(selectedColor)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AgentOSTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .agentOSInputChrome(
                    background: isHovering ? AgentOSTheme.inputHoverSurface : AgentOSTheme.inputSurface
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .onHover { isHovering = $0 }
            .pointingHandCursor()
            .accessibilityLabel(label)
            .accessibilityValue(selectedTitle)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AgentOSSelectWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
        }
        .onPreferenceChange(AgentOSSelectWidthPreferenceKey.self) { width in
            triggerWidth = width
        }
        .popover(isPresented: $isExpanded, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            optionsPanel
                .frame(width: triggerWidth)
                .presentationBackground(AgentOSTheme.popover)
        }
        .onExitCommand {
            isExpanded = false
        }
        .animation(.easeOut(duration: 0.12), value: isExpanded)
    }

    private var optionsPanel: some View {
        VStack(spacing: 2) {
            ForEach(options) { option in
                Button {
                    onSelect(option.id)
                    isExpanded = false
                } label: {
                    HStack(spacing: 8) {
                        if let systemImage = option.systemImage {
                            Image(systemName: systemImage)
                                .font(.callout)
                                .foregroundStyle(option.tint)
                                .frame(width: 18, height: 20)
                        }

                        Text(option.title)
                            .font(.callout)
                            .foregroundStyle(AgentOSTheme.popoverForeground)

                        Spacer(minLength: 8)

                        if option.id == selectedID {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(option.tint)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: AgentOSMetrics.compactControlHeight)
                    .background(
                        option.id == selectedID || hoveredOptionID == option.id
                            ? AgentOSTheme.interactiveAccent
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusSmall, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    hoveredOptionID = isHovering
                        ? option.id
                        : (hoveredOptionID == option.id ? nil : hoveredOptionID)
                }
                .pointingHandCursor()
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            AgentOSTheme.popover,
            in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                .stroke(AgentOSTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

private struct AgentOSSelectWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 240

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
