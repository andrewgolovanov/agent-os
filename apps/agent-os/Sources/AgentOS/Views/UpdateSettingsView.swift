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
                    if let plugin = store.componentUpdateStatus?.plugin {
                        LabeledContent("Codex plugin", value: plugin.installedVersion ?? "Not installed")
                    } else {
                        LabeledContent(
                            "Codex plugin",
                            value: store.isCheckingForComponentUpdates ? "Checking…" : "Unknown"
                        )
                    }
                    if let plugin = store.componentUpdateStatus?.plugin,
                       plugin.refreshRequired,
                       let version = plugin.sourceVersion
                    {
                        LabeledContent("Available plugin", value: version)
                    }

                    Toggle("Update Codex plugin automatically after app updates", isOn: $automaticallyUpdatesCorePlugin)
                        .disabled(
                            store.isCheckingForComponentUpdates
                                || store.componentUpdateStatus?.plugin.installed != true
                        )

                    HStack {
                        Button("Check Codex Plugin") {
                            Task { await store.checkForComponentUpdates() }
                        }
                        .disabled(store.isCheckingForComponentUpdates)
                        Button("Install Codex Plugin Update") {
                            Task { await store.checkForComponentUpdates(apply: true) }
                        }
                        .disabled(
                            store.isCheckingForComponentUpdates
                                || store.componentUpdateStatus?.plugin.canInstallUpdate != true
                        )
                        if store.isCheckingForComponentUpdates {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Updating Agent OS components")
                        }
                    }

                    if let plugin = store.componentUpdateStatus?.plugin,
                       let reason = plugin.reason,
                       ["manual-update-required", "installed-newer-than-runtime"].contains(plugin.action)
                    {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("The app updates through Sparkle. Its companion plugin follows the same verified release tag through the official Codex marketplace; the private registry and task history are preserved. Start a fresh Codex task after a plugin update.")
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
                        .disabled(store.isCheckingForComponentUpdates)
                        Button("Install Core and Plugin Update") {
                            Task { await store.checkForComponentUpdates(apply: true) }
                        }
                        .disabled(
                            store.isCheckingForComponentUpdates
                                || store.componentUpdateStatus?.source.updateAvailable != true
                        )
                        if store.isCheckingForComponentUpdates {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Updating Agent OS components")
                        }
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
