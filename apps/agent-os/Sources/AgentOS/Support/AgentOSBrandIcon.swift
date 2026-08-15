import AppKit

enum AgentOSBrandIcon {
    static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            // Preserve the supplied SVG geometry while fitting its visible mark
            // into the standard 18-point menu-bar canvas.
            let sourceBounds = CGRect(x: 72, y: 116, width: 1_072, height: 962)
            let scale = min(17 / sourceBounds.width, 16 / sourceBounds.height)
            context.translateBy(x: 9, y: 9)
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: -sourceBounds.midX, y: -sourceBounds.midY)

            context.setFillColor(NSColor.black.cgColor)
            context.addPath(makeMarkPath())
            context.fillPath()

            context.setBlendMode(.clear)
            context.addPath(makeLowerCutoutPath())
            context.fillPath()
            context.restoreGState()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Agent OS"
        return image
    }()

    private static func makeMarkPath() -> CGPath {
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 608, y: 116))
        path.addCurve(to: CGPoint(x: 425, y: 247), control1: CGPoint(x: 520, y: 116), control2: CGPoint(x: 465, y: 165))
        path.addLine(to: CGPoint(x: 107, y: 809))
        path.addCurve(to: CGPoint(x: 164, y: 1_016), control1: CGPoint(x: 72, y: 871), control2: CGPoint(x: 99, y: 964))
        path.addCurve(to: CGPoint(x: 406, y: 1_017), control1: CGPoint(x: 230, y: 1_068), control2: CGPoint(x: 340, y: 1_078))
        path.addCurve(to: CGPoint(x: 470, y: 913), control1: CGPoint(x: 433, y: 992), control2: CGPoint(x: 450, y: 953))
        path.addLine(to: CGPoint(x: 550, y: 769))
        path.addCurve(to: CGPoint(x: 608, y: 751), control1: CGPoint(x: 566, y: 741), control2: CGPoint(x: 585, y: 751))
        path.addCurve(to: CGPoint(x: 666, y: 769), control1: CGPoint(x: 631, y: 751), control2: CGPoint(x: 650, y: 741))
        path.addLine(to: CGPoint(x: 746, y: 913))
        path.addCurve(to: CGPoint(x: 810, y: 1_017), control1: CGPoint(x: 766, y: 953), control2: CGPoint(x: 783, y: 992))
        path.addCurve(to: CGPoint(x: 1_052, y: 1_016), control1: CGPoint(x: 876, y: 1_078), control2: CGPoint(x: 986, y: 1_068))
        path.addCurve(to: CGPoint(x: 1_109, y: 809), control1: CGPoint(x: 1_117, y: 964), control2: CGPoint(x: 1_144, y: 871))
        path.addLine(to: CGPoint(x: 791, y: 247))
        path.addCurve(to: CGPoint(x: 608, y: 116), control1: CGPoint(x: 751, y: 165), control2: CGPoint(x: 696, y: 116))
        path.closeSubpath()

        path.move(to: CGPoint(x: 608, y: 426))
        path.addCurve(to: CGPoint(x: 763, y: 527), control1: CGPoint(x: 676, y: 426), control2: CGPoint(x: 730, y: 462))
        path.addLine(to: CGPoint(x: 955, y: 866))
        path.addCurve(to: CGPoint(x: 942, y: 913), control1: CGPoint(x: 968, y: 889), control2: CGPoint(x: 958, y: 913))
        path.addCurve(to: CGPoint(x: 917, y: 894), control1: CGPoint(x: 931, y: 913), control2: CGPoint(x: 924, y: 906))
        path.addLine(to: CGPoint(x: 770, y: 630))
        path.addCurve(to: CGPoint(x: 608, y: 744), control1: CGPoint(x: 750, y: 692), control2: CGPoint(x: 691, y: 744))
        path.addCurve(to: CGPoint(x: 446, y: 630), control1: CGPoint(x: 525, y: 744), control2: CGPoint(x: 466, y: 692))
        path.addLine(to: CGPoint(x: 299, y: 894))
        path.addCurve(to: CGPoint(x: 274, y: 913), control1: CGPoint(x: 292, y: 906), control2: CGPoint(x: 285, y: 913))
        path.addCurve(to: CGPoint(x: 261, y: 866), control1: CGPoint(x: 258, y: 913), control2: CGPoint(x: 248, y: 889))
        path.addLine(to: CGPoint(x: 453, y: 527))
        path.addCurve(to: CGPoint(x: 608, y: 426), control1: CGPoint(x: 486, y: 462), control2: CGPoint(x: 540, y: 426))
        path.closeSubpath()

        return path
    }

    private static func makeLowerCutoutPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 608, y: 700))
        path.addCurve(to: CGPoint(x: 690, y: 790), control1: CGPoint(x: 649, y: 700), control2: CGPoint(x: 668, y: 749))
        path.addLine(to: CGPoint(x: 749, y: 900))
        path.addCurve(to: CGPoint(x: 842, y: 1_042), control1: CGPoint(x: 776, y: 951), control2: CGPoint(x: 798, y: 1_007))
        path.addLine(to: CGPoint(x: 374, y: 1_042))
        path.addCurve(to: CGPoint(x: 467, y: 900), control1: CGPoint(x: 418, y: 1_007), control2: CGPoint(x: 440, y: 951))
        path.addLine(to: CGPoint(x: 526, y: 790))
        path.addCurve(to: CGPoint(x: 608, y: 700), control1: CGPoint(x: 548, y: 749), control2: CGPoint(x: 567, y: 700))
        path.closeSubpath()
        return path
    }
}
