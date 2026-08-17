import AppKit
import SwiftUI

enum AgentOSTheme {
    // The official shadcn/ui default Neutral light and dark semantic tokens,
    // translated from the documented OKLCH values to their sRGB equivalents.
    // Keep component code on these roles instead of adding per-theme colors.
    static let background = adaptive(light: neutral0, dark: neutral950)
    static let foreground = adaptive(light: neutral950, dark: neutral50)
    static let card = adaptive(light: neutral0, dark: neutral900)
    static let cardForeground = adaptive(light: neutral950, dark: neutral50)
    static let popover = adaptive(light: neutral0, dark: neutral900)
    static let popoverForeground = adaptive(light: neutral950, dark: neutral50)
    static let primary = adaptive(light: neutral900, dark: neutral200)
    static let primaryForeground = adaptive(light: neutral50, dark: neutral900)
    static let secondary = adaptive(light: neutral100, dark: neutral800)
    static let secondaryForeground = adaptive(light: neutral900, dark: neutral50)
    static let muted = adaptive(light: neutral100, dark: neutral800)
    static let mutedForeground = adaptive(light: neutral500, dark: neutral400)
    static let interactiveAccent = adaptive(light: neutral100, dark: neutral800)
    static let interactiveAccentForeground = adaptive(light: neutral900, dark: neutral50)
    static let border = adaptive(light: neutral200, dark: NSColor.white.withAlphaComponent(0.10))
    static let input = adaptive(light: neutral200, dark: NSColor.white.withAlphaComponent(0.15))
    static let inputSurface = adaptive(light: neutral50, dark: NSColor.white.withAlphaComponent(0.045))
    static let inputHoverSurface = adaptive(light: neutral100, dark: NSColor.white.withAlphaComponent(0.075))
    static let ring = adaptive(light: neutral400, dark: neutral500)
    static let sidebar = adaptive(light: neutral50, dark: neutral900)
    static let sidebarForeground = adaptive(light: neutral950, dark: neutral50)
    static let sidebarAccent = adaptive(light: neutral100, dark: neutral800)
    static let sidebarAccentForeground = adaptive(light: neutral900, dark: neutral50)
    static let sidebarBorder = adaptive(light: neutral200, dark: NSColor.white.withAlphaComponent(0.10))
    static let inspectorBackdrop = Color.black.opacity(0.48)

    static let canvas = background
    static let surface = card
    static let surfaceRaised = card
    static let surfaceHover = interactiveAccent
    static let borderStrong = input
    static let textPrimary = foreground
    static let textSecondary = mutedForeground
    static let textTertiary = adaptive(light: neutral500, dark: neutral500)
    static let accent = primary
    static let accentForeground = primaryForeground
    static let information = adaptive(
        light: rgb(37, 99, 235),
        dark: rgb(96, 165, 250)
    )
    static let warning = adaptive(
        light: rgb(180, 83, 9),
        dark: rgb(251, 191, 36)
    )

    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        )
    }

    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }

    private static let neutral0 = rgb(255, 255, 255)
    private static let neutral50 = rgb(250, 250, 250)
    private static let neutral100 = rgb(245, 245, 245)
    private static let neutral200 = rgb(229, 229, 229)
    private static let neutral400 = rgb(163, 163, 163)
    private static let neutral500 = rgb(115, 115, 115)
    private static let neutral800 = rgb(38, 38, 38)
    private static let neutral900 = rgb(23, 23, 23)
    private static let neutral950 = rgb(10, 10, 10)
}

enum AgentOSMetrics {
    static let grid: CGFloat = 4
    static let headerHeight: CGFloat = 48
    static let sidebarWidth: CGFloat = 240
    static let inspectorMinWidth: CGFloat = 420
    static let inspectorIdealWidth: CGFloat = 520
    static let inspectorMaxWidth: CGFloat = 680
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
