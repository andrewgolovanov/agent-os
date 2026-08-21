import Foundation
import Observation

@MainActor
@Observable
final class AgentOSStore {
    private(set) var projects: [AgentOSProject] = []
    private(set) var tasks: [AgentOSTask] = []
    private(set) var isRefreshing = false
    private(set) var busyTaskID: String?
    private(set) var lastRefreshedAt: Date?
    private(set) var componentUpdateStatus: AgentOSUpdateStatus?
    private(set) var projectSyncReport: AgentOSProjectSyncReport?
    private(set) var isCheckingForComponentUpdates = false
    private(set) var sourceMetadata: [String: AgentOSSourceMetadata] = [:]
    private(set) var loadingSourceIDs: Set<String> = []
    var errorMessage: String?
    var noticeMessage: String?

    let configuration: AgentOSConfiguration

    private let agentOSService = AgentOSCLIService()
    private let codexService = CodexAppServerService()
    private let sourceMetadataService = SourceMetadataService()
    private var watcher: AgentOSFileWatcher?

    init(configuration: AgentOSConfiguration? = nil) {
        self.configuration = configuration ?? AgentOSRuntimeBootstrap.prepare()
    }

    var unfinishedTasks: [AgentOSTask] {
        tasks.filter { $0.status.isUnfinished }
    }

    var attentionTasks: [AgentOSTask] {
        tasks.filter { [.active, .waiting, .review].contains($0.status) }
    }

    var completedTasks: [AgentOSTask] {
        tasks.filter { !$0.status.isUnfinished }
    }

    func bootstrap() async {
        installWatchersIfAvailable()
        await synchronizeCodexProjects()
        await refresh()
        let packagedRuntime = FileManager.default.fileExists(
            atPath: configuration.sourceURL.appendingPathComponent(".agent-os-runtime.json").path
        )
        await checkForComponentUpdates(
            apply: !packagedRuntime && UserDefaults.standard.bool(forKey: "agent-os.auto-update-core-plugin"),
            announceCurrent: false
        )
    }

    private func synchronizeCodexProjects() async {
        do {
            let workingDirectories = try await codexService.activeWorkingDirectories(
                startingAt: configuration.homeURL
            )
            let report = try await agentOSService.syncCodexProjects(
                configuration: configuration,
                workingDirectories: workingDirectories
            )
            projectSyncReport = report
            let changedCount = report.registeredCount + report.enrichedCount + report.refreshedCount
            if changedCount > 0 {
                let suffix = report.skippedCount > 0 ? "; skipped \(report.skippedCount) ambiguous or unavailable paths" : ""
                noticeMessage = "Synchronized \(changedCount) Codex project\(changedCount == 1 ? "" : "s")\(suffix)."
            }
        } catch {
            noticeMessage = "Codex project synchronization was unavailable: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snapshot = try await agentOSService.loadSnapshot(configuration: configuration)
            projects = snapshot.projects.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            tasks = snapshot.tasks.sorted { $0.updatedAt > $1.updatedAt }
            installWatchersIfAvailable()
            lastRefreshedAt = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installWatchersIfAvailable() {
        if watcher == nil {
            do {
                watcher = try AgentOSFileWatcher(
                    directory: configuration.homeURL.appendingPathComponent("work", isDirectory: true)
                ) { [weak self] in
                    Task { await self?.refresh() }
                }
            } catch {
                errorMessage = "Live refresh unavailable: \(error.localizedDescription)"
            }
        }
    }

    func createTask(title: String, project: String?, goal: String, nextAction: String) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !goal.isEmpty, !nextAction.isEmpty else {
            errorMessage = "Title, goal, and next action are required."
            return false
        }

        do {
            try await agentOSService.createTask(
                configuration: configuration,
                title: title,
                project: project,
                goal: goal,
                nextAction: nextAction
            )
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateStatus(taskID: String, status: TaskStatus) async {
        busyTaskID = taskID
        defer { busyTaskID = nil }
        do {
            try await agentOSService.updateStatus(
                configuration: configuration,
                taskID: taskID,
                status: status
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCompletionFollowUp(taskID: String, status: AgentOSCompletionFollowUpStatus) async {
        busyTaskID = taskID
        defer { busyTaskID = nil }
        do {
            try await agentOSService.updateCompletionFollowUp(
                configuration: configuration,
                taskID: taskID,
                status: status
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyCompletionUpdate(taskID: String) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }

        let pullRequests = task.sources.pullRequestItems.map { item -> String in
            let metadata = sourceMetadata[item.id] ?? AgentOSSourcePresentation.localMetadata(for: item)
            let status = metadata.status.map { " — \($0)" } ?? ""
            return "- \(metadata.title)\(status): \(item.link.url)"
        }
        let project = task.projects.isEmpty ? "Unassigned" : task.projects.joined(separator: ", ")
        let labels = task.labels.map(\.name).joined(separator: ", ")
        let labelsLine = labels.isEmpty ? "" : "\nLabels: \(labels)"
        let pullRequestSection = pullRequests.isEmpty
            ? ""
            : "\n\nPull requests:\n\(pullRequests.joined(separator: "\n"))"
        let update = """
        ✅ \(task.title)

        Project: \(project)\(labelsLine)

        \(task.summary)\(pullRequestSection)
        """

        do {
            try CodexHandoffService.copyPrompt(update)
            noticeMessage = "Completion update copied. Send it in the relevant Slack thread, then mark follow-up as Sent."
        } catch {
            errorMessage = "Could not copy completion update: \(error.localizedDescription)"
        }
    }

    func openNewCodexTask(taskID: String) async {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        guard task.projects.count == 1, let projectKey = task.projects.first,
              let project = projects.first(where: { $0.key == projectKey })
        else {
            errorMessage = "Opening a new Codex task requires exactly one registered project."
            return
        }

        busyTaskID = taskID
        defer { busyTaskID = nil }
        do {
            let prompt = """
            Continue the canonical Agent OS outcome \(task.id): \(task.title)

            Goal: \(task.goal)
            Current summary: \(task.summary)
            Next action: \(task.nextAction)

            Work only in the registered project at \(project.preferredWorkingDirectory.path). Read its closest AGENTS.md before mutations. Keep the Task Board outcome current through the existing Agent OS workflow.
            """
            let threadID = try await codexService.createTask(
                workingDirectory: project.preferredWorkingDirectory,
                title: task.title
            )
            try await agentOSService.attachCodex(
                configuration: configuration,
                taskID: task.id,
                threadID: threadID,
                project: project.key,
                title: task.title,
                status: "idle"
            )
            try CodexHandoffService.copyPrompt(prompt)
            try await Task.sleep(for: .milliseconds(500))
            try await CodexHandoffService.open(threadID: threadID)
            noticeMessage = "Opened the exact Codex task. Its prepared prompt is on the clipboard."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openCodexTask(threadID: String) async {
        do {
            try await CodexHandoffService.open(threadID: threadID)
        } catch {
            errorMessage = "Codex handoff failed: \(error.localizedDescription)"
        }
    }

    func loadSourceMetadata(for task: AgentOSTask) async {
        let items = task.sources.items.filter { $0.kind == .pullRequest }
        let itemIDs = Set(items.map(\.id))
        guard !itemIDs.isEmpty else { return }

        loadingSourceIDs.formUnion(itemIDs)
        defer { loadingSourceIDs.subtract(itemIDs) }

        let loaded = await sourceMetadataService.load(for: items)
        sourceMetadata.merge(loaded) { _, refreshed in refreshed }
    }

    func checkForComponentUpdates(apply: Bool = false, announceCurrent: Bool = true) async {
        guard !isCheckingForComponentUpdates else { return }
        isCheckingForComponentUpdates = true
        defer { isCheckingForComponentUpdates = false }

        do {
            let status = try await agentOSService.updateAgentOS(configuration: configuration, apply: apply)
            componentUpdateStatus = status
            if status.updated == true || status.plugin.updated {
                noticeMessage = "Agent OS core/plugin updated. Start a fresh Codex task to load the refreshed plugin."
            } else if status.source.updateAvailable, let latest = status.source.latestVersion {
                noticeMessage = "Agent OS \(latest) is available. Open Settings → Updates to install it."
            } else if announceCurrent, status.source.action == "managed-by-app" {
                noticeMessage = "Agent OS runtime is bundled with the app. Codex manages plugin updates separately."
            } else if announceCurrent, status.source.configured {
                noticeMessage = "Agent OS core and Codex plugin are up to date."
            }
        } catch {
            if apply || announceCurrent {
                errorMessage = "Update check failed: \(error.localizedDescription)"
            }
        }
    }
}
