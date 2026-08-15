import AppKit

enum AgentOSBrandIcon {
    static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.translateBy(x: 9, y: 10.4)
            context.scaleBy(x: 1.2, y: 1.2)
            context.translateBy(x: -9, y: -10.4)
            context.setFillColor(NSColor.black.cgColor)

            let mark = CGMutablePath()
            mark.move(to: CGPoint(x: 9, y: 16))
            mark.addCurve(
                to: CGPoint(x: 7.1, y: 14.7),
                control1: CGPoint(x: 8.2, y: 16),
                control2: CGPoint(x: 7.5, y: 15.5)
            )
            mark.addLine(to: CGPoint(x: 3.2, y: 7.6))
            mark.addCurve(
                to: CGPoint(x: 4.1, y: 5.2),
                control1: CGPoint(x: 2.7, y: 6.7),
                control2: CGPoint(x: 3.2, y: 5.6)
            )
            mark.addCurve(
                to: CGPoint(x: 6.7, y: 6.1),
                control1: CGPoint(x: 5.1, y: 4.8),
                control2: CGPoint(x: 6.2, y: 5.2)
            )
            mark.addLine(to: CGPoint(x: 8.55, y: 8.4))
            mark.addCurve(
                to: CGPoint(x: 9, y: 8.95),
                control1: CGPoint(x: 8.75, y: 8.65),
                control2: CGPoint(x: 8.85, y: 8.95)
            )
            mark.addCurve(
                to: CGPoint(x: 9.45, y: 8.4),
                control1: CGPoint(x: 9.15, y: 8.95),
                control2: CGPoint(x: 9.25, y: 8.65)
            )
            mark.addLine(to: CGPoint(x: 11.3, y: 6.1))
            mark.addCurve(
                to: CGPoint(x: 13.9, y: 5.2),
                control1: CGPoint(x: 11.8, y: 5.2),
                control2: CGPoint(x: 12.9, y: 4.8)
            )
            mark.addCurve(
                to: CGPoint(x: 14.8, y: 7.6),
                control1: CGPoint(x: 14.8, y: 5.6),
                control2: CGPoint(x: 15.3, y: 6.7)
            )
            mark.addLine(to: CGPoint(x: 10.9, y: 14.7))
            mark.addCurve(
                to: CGPoint(x: 9, y: 16),
                control1: CGPoint(x: 10.5, y: 15.5),
                control2: CGPoint(x: 9.8, y: 16)
            )
            mark.closeSubpath()
            context.addPath(mark)
            context.fillPath()

            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: 7.15, y: 8.95, width: 3.7, height: 3.7))
            context.setLineCap(.round)
            context.setLineWidth(0.72)
            context.move(to: CGPoint(x: 7.9, y: 9.9))
            context.addLine(to: CGPoint(x: 5.2, y: 6.25))
            context.move(to: CGPoint(x: 10.1, y: 9.9))
            context.addLine(to: CGPoint(x: 12.8, y: 6.25))
            context.strokePath()
            context.restoreGState()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Agent OS"
        return image
    }()
}
