import AppKit
import SwiftUI

struct MenuBarView: View {
    let store: AgentOSStore
    let updater: AgentOSUpdaterController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Agent OS") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        if !store.attentionTasks.isEmpty {
            Divider()
            ForEach(store.attentionTasks.prefix(5)) { task in
                Button(shortTitle(task.title)) {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        Divider()
        Button("Refresh") { Task { await store.refresh() } }
        Button("Check for Updates…") {
            updater.checkForUpdates()
            Task { await store.checkForComponentUpdates() }
        }
        SettingsLink()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func shortTitle(_ title: String) -> String {
        guard title.count > 30 else { return title }
        return String(title.prefix(27)) + "..."
    }
}
