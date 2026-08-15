import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct AgentOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AgentOSStore()
    private let updater = AgentOSUpdaterController()

    private var forcedColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--force-light-appearance") { return .light }
        if arguments.contains("--force-dark-appearance") { return .dark }
        return nil
    }

    var body: some Scene {
        WindowGroup("Agent OS", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1_080, minHeight: 680)
                .preferredColorScheme(forcedColorScheme)
        }
        .defaultSize(width: 1_360, height: 820)

        MenuBarExtra("Agent OS", systemImage: "rectangle.3.group") {
            MenuBarView(store: store, updater: updater)
                .preferredColorScheme(forcedColorScheme)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            UpdateSettingsView(store: store, updater: updater)
                .preferredColorScheme(forcedColorScheme)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                    Task { await store.checkForComponentUpdates() }
                }
            }
        }
    }
}
