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

    private var appColorScheme: ColorScheme {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--force-light-appearance") { return .light }
        return .dark
    }

    var body: some Scene {
        WindowGroup("Agent OS", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1_080, minHeight: 680)
                .preferredColorScheme(appColorScheme)
        }
        .defaultSize(width: 1_360, height: 820)

        MenuBarExtra {
            MenuBarView(store: store, updater: updater)
                .preferredColorScheme(appColorScheme)
        } label: {
            Image(nsImage: AgentOSBrandIcon.menuBarImage)
                .accessibilityLabel("Agent OS")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            UpdateSettingsView(store: store, updater: updater)
                .preferredColorScheme(appColorScheme)
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
