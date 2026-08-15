import SwiftUI

struct UpdateSettingsView: View {
    let store: AgentOSStore
    let updater: AgentOSUpdaterController
    @State private var automaticallyChecks: Bool
    @State private var automaticallyDownloads: Bool
    @AppStorage("agent-os.auto-update-core-plugin") private var automaticallyUpdatesCorePlugin = false

    init(store: AgentOSStore, updater: AgentOSUpdaterController) {
        self.store = store
        self.updater = updater
        _automaticallyChecks = State(initialValue: updater.automaticallyChecksForUpdates)
        _automaticallyDownloads = State(initialValue: updater.automaticallyDownloadsUpdates)
    }

    var body: some View {
        Form {
            Section("Agent OS runtime and Codex plugin") {
                if usesPackagedRuntime {
                    LabeledContent("Runtime", value: "Bundled with app")
                    if let version = store.componentUpdateStatus?.source.currentVersion {
                        LabeledContent("Version", value: version)
                    }
                    if let version = store.componentUpdateStatus?.plugin.installedVersion {
                        LabeledContent("Codex plugin", value: version)
                    }
                    Text("The runtime updates together with the macOS app. Codex owns the separately installed plugin and its updates; no Agent OS source checkout is required.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle("Install tagged Agent OS releases automatically", isOn: $automaticallyUpdatesCorePlugin)

                    if let source = store.componentUpdateStatus?.source,
                       source.updateAvailable,
                       let latest = source.latestVersion
                    {
                        Text("Version \(latest) is available.")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Check Core and Plugin") {
                            Task { await store.checkForComponentUpdates() }
                        }
                        Button("Install Core and Plugin Update") {
                            Task { await store.checkForComponentUpdates(apply: true) }
                        }
                        .disabled(store.componentUpdateStatus?.source.updateAvailable != true)
                    }

                    Text("Development checkout updates are accepted only from version tags and only as a clean fast-forward. Local changes and diverged checkouts are never overwritten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("macOS app") {
            Toggle("Check for updates automatically", isOn: $automaticallyChecks)
                .onChange(of: automaticallyChecks) { _, enabled in
                    updater.automaticallyChecksForUpdates = enabled
                }

            Toggle("Download and install updates automatically", isOn: $automaticallyDownloads)
                .disabled(!automaticallyChecks)
                .onChange(of: automaticallyDownloads) { _, enabled in
                    updater.automaticallyDownloadsUpdates = enabled
                }

            Text("Automatic installation is optional. Every app archive is verified with the Agent OS Ed25519 update key before it is installed.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Check Now") {
                updater.checkForUpdates()
            }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560)
        .background(AgentOSTheme.canvas)
        .tint(AgentOSTheme.accent)
    }

    private var usesPackagedRuntime: Bool {
        store.componentUpdateStatus?.source.action == "managed-by-app"
            || FileManager.default.fileExists(
                atPath: store.configuration.sourceURL.appendingPathComponent(".agent-os-runtime.json").path
            )
    }
}
