import AppKit
import SwiftUI

private struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            switch phase {
            case .active:
                NSCursor.pointingHand.set()
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }
}

private struct HorizontalResizeCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            switch phase {
            case .active:
                NSCursor.resizeLeftRight.set()
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }

    func horizontalResizeCursor() -> some View {
        modifier(HorizontalResizeCursorModifier())
    }
}
