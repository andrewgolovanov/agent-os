import AppKit
import SwiftUI

struct WindowSidebarDivider: NSViewRepresentable {
    let sidebarWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowProbeView {
        let view = WindowProbeView()
        view.onWindowChange = { window in
            context.coordinator.install(in: window, sidebarWidth: sidebarWidth)
        }
        return view
    }

    func updateNSView(_ nsView: WindowProbeView, context: Context) {
        context.coordinator.install(in: nsView.window, sidebarWidth: sidebarWidth)
    }

    static func dismantleNSView(_ nsView: WindowProbeView, coordinator: Coordinator) {
        nsView.onWindowChange = nil
        coordinator.removeDivider()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private weak var titlebarFill: NSView?
        private weak var contentTitlebarFill: NSView?
        private weak var divider: NSView?
        private var titlebarWidthConstraint: NSLayoutConstraint?
        private var titlebarHeightConstraint: NSLayoutConstraint?
        private var contentTitlebarHeightConstraint: NSLayoutConstraint?
        private var contentTitlebarLeadingConstraint: NSLayoutConstraint?
        private var dividerLeadingConstraint: NSLayoutConstraint?

        func install(in window: NSWindow?, sidebarWidth: CGFloat) {
            guard let window, let contentView = window.contentView else {
                removeDivider()
                return
            }

            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar?.showsBaselineSeparator = false

            if installedWindow !== window
                || titlebarFill?.superview !== contentView
                || contentTitlebarFill?.superview !== contentView
                || divider?.superview !== contentView
            {
                removeDivider()

                let titlebarFill = PassthroughDividerView()
                titlebarFill.wantsLayer = true
                titlebarFill.layer?.backgroundColor = NSColor(AgentOSTheme.sidebar).cgColor
                titlebarFill.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(titlebarFill, positioned: .above, relativeTo: nil)

                let contentTitlebarFill = PassthroughDividerView()
                contentTitlebarFill.wantsLayer = true
                contentTitlebarFill.layer?.backgroundColor = NSColor(AgentOSTheme.canvas).cgColor
                contentTitlebarFill.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(contentTitlebarFill, positioned: .above, relativeTo: titlebarFill)

                let divider = PassthroughDividerView()
                divider.wantsLayer = true
                divider.layer?.backgroundColor = NSColor(AgentOSTheme.sidebarBorder).cgColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(divider, positioned: .above, relativeTo: contentTitlebarFill)

                let titlebarWidthConstraint = titlebarFill.widthAnchor.constraint(equalToConstant: sidebarWidth)
                let titlebarHeightConstraint = titlebarFill.heightAnchor.constraint(
                    equalToConstant: titlebarHeight(in: window, contentView: contentView)
                )
                let contentTitlebarHeightConstraint = contentTitlebarFill.heightAnchor.constraint(
                    equalToConstant: titlebarHeight(in: window, contentView: contentView)
                )
                let contentTitlebarLeadingConstraint = contentTitlebarFill.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: sidebarWidth
                )

                let dividerLeadingConstraint = divider.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: sidebarWidth
                )
                NSLayoutConstraint.activate([
                    titlebarFill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    titlebarFill.topAnchor.constraint(equalTo: contentView.topAnchor),
                    titlebarWidthConstraint,
                    titlebarHeightConstraint,
                    contentTitlebarLeadingConstraint,
                    contentTitlebarFill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    contentTitlebarFill.topAnchor.constraint(equalTo: contentView.topAnchor),
                    contentTitlebarHeightConstraint,
                    dividerLeadingConstraint,
                    divider.topAnchor.constraint(equalTo: contentView.topAnchor),
                    divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 1),
                ])

                installedWindow = window
                self.titlebarFill = titlebarFill
                self.contentTitlebarFill = contentTitlebarFill
                self.divider = divider
                self.titlebarWidthConstraint = titlebarWidthConstraint
                self.titlebarHeightConstraint = titlebarHeightConstraint
                self.contentTitlebarHeightConstraint = contentTitlebarHeightConstraint
                self.contentTitlebarLeadingConstraint = contentTitlebarLeadingConstraint
                self.dividerLeadingConstraint = dividerLeadingConstraint
            } else {
                titlebarWidthConstraint?.constant = sidebarWidth
                titlebarHeightConstraint?.constant = titlebarHeight(in: window, contentView: contentView)
                contentTitlebarHeightConstraint?.constant = titlebarHeight(in: window, contentView: contentView)
                contentTitlebarLeadingConstraint?.constant = sidebarWidth
                dividerLeadingConstraint?.constant = sidebarWidth
            }
        }

        func removeDivider() {
            titlebarWidthConstraint = nil
            titlebarHeightConstraint = nil
            contentTitlebarHeightConstraint = nil
            contentTitlebarLeadingConstraint = nil
            dividerLeadingConstraint = nil
            titlebarFill?.removeFromSuperview()
            contentTitlebarFill?.removeFromSuperview()
            divider?.removeFromSuperview()
            titlebarFill = nil
            contentTitlebarFill = nil
            divider = nil
            installedWindow = nil
        }

        private func titlebarHeight(in window: NSWindow, contentView: NSView) -> CGFloat {
            max(
                AgentOSMetrics.headerHeight,
                contentView.bounds.height - window.contentLayoutRect.height
            )
        }
    }
}

final class WindowProbeView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

private final class PassthroughDividerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
