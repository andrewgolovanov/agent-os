import SwiftUI

enum AgentOSTheme {
    // The official shadcn/ui default Neutral dark tokens, translated from the
    // documented OKLCH values to their sRGB equivalents. Keep component code
    // on these semantic roles instead of introducing one-off gray surfaces.
    static let background = neutral950
    static let foreground = neutral50
    static let card = neutral900
    static let cardForeground = neutral50
    static let popover = neutral900
    static let popoverForeground = neutral50
    static let primary = neutral200
    static let primaryForeground = neutral900
    static let secondary = neutral800
    static let secondaryForeground = neutral50
    static let muted = neutral800
    static let mutedForeground = neutral400
    static let interactiveAccent = neutral800
    static let interactiveAccentForeground = neutral50
    static let border = Color.white.opacity(0.10)
    static let input = Color.white.opacity(0.15)
    static let inputSurface = Color.white.opacity(0.045)
    static let inputHoverSurface = Color.white.opacity(0.075)
    static let ring = neutral500
    static let sidebar = neutral900
    static let sidebarForeground = neutral50
    static let sidebarAccent = neutral800
    static let sidebarAccentForeground = neutral50
    static let sidebarBorder = Color.white.opacity(0.10)
    static let inspectorBackdrop = Color.black.opacity(0.48)

    static let canvas = background
    static let surface = card
    static let surfaceRaised = card
    static let surfaceHover = interactiveAccent
    static let borderStrong = input
    static let textPrimary = foreground
    static let textSecondary = mutedForeground
    static let textTertiary = neutral500
    static let accent = primary
    static let accentForeground = primaryForeground
    static let information = Color(red: 0.376, green: 0.647, blue: 0.980)
    static let warning = Color(red: 0.984, green: 0.749, blue: 0.141)

    private static let neutral50 = Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    private static let neutral200 = Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
    private static let neutral400 = Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255)
    private static let neutral500 = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255)
    private static let neutral800 = Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255)
    private static let neutral900 = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    private static let neutral950 = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
}

enum AgentOSMetrics {
    static let grid: CGFloat = 4
    static let headerHeight: CGFloat = 48
    static let sidebarWidth: CGFloat = 240
    static let contentPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 16
    static let controlHeight: CGFloat = 36
    static let compactControlHeight: CGFloat = 32
    static let iconSize: CGFloat = 16
    static let statusMarkerDiameter: CGFloat = 24
    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 10
    static let radiusExtraLarge: CGFloat = 14
}

struct AgentOSPanel: ViewModifier {
    let cornerRadius: CGFloat
    let background: Color
    let border: Color

    func body(content: Content) -> some View {
        content
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
    }
}

private struct AgentOSInputChrome: ViewModifier {
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let alignment: Alignment
    let background: Color

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                maxHeight: maxHeight,
                alignment: alignment
            )
            .background(
                background,
                in: RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AgentOSMetrics.radiusMedium, style: .continuous)
                    .stroke(AgentOSTheme.input, lineWidth: 1)
            }
    }
}

extension View {
    func agentOSPanel(
        cornerRadius: CGFloat = AgentOSMetrics.radiusLarge,
        background: Color = AgentOSTheme.surface,
        border: Color = AgentOSTheme.border
    ) -> some View {
        modifier(AgentOSPanel(cornerRadius: cornerRadius, background: background, border: border))
    }

    func agentOSInputChrome(
        height: CGFloat = AgentOSMetrics.controlHeight,
        alignment: Alignment = .center,
        background: Color = AgentOSTheme.inputSurface
    ) -> some View {
        modifier(
            AgentOSInputChrome(
                minHeight: height,
                maxHeight: height,
                alignment: alignment,
                background: background
            )
        )
    }

    func agentOSMultilineInputChrome(minHeight: CGFloat) -> some View {
        modifier(
            AgentOSInputChrome(
                minHeight: minHeight,
                maxHeight: nil,
                alignment: .topLeading,
                background: AgentOSTheme.inputSurface
            )
        )
    }
}
