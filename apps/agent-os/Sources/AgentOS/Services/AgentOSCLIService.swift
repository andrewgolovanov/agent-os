import Foundation

struct AgentOSCLIService: Sendable {
    private static let projectRegistryScript = #"""
    data = YAML.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [], permitted_symbols: [], aliases: false)
    projects = data.fetch("projects").map do |key, value|
      {
        key: key,
        displayName: value.fetch("display_name"),
        status: value.fetch("status"),
        root: value.fetch("root"),
        slackChannels: Array(value["slack_channels"]).map do |channel|
          {
            id: channel.fetch("id"),
            name: channel.fetch("name")
          }
        end,
        repositories: Array(value["repositories"]).map do |repository|
          {
            id: repository.fetch("id"),
            path: repository.fetch("path"),
            role: repository.fetch("role"),
            sourceOfTruth: repository.fetch("source_of_truth", "unknown"),
            primaryBranch: repository.fetch("primary_branch", "unknown")
          }
        end
      }
    end
    puts JSON.generate(projects)
    """#

    func loadSnapshot(configuration: AgentOSConfiguration) async throws -> AgentOSSnapshot {
        try validate(configuration)
        let projects = try await loadProjects(home: configuration.homeURL)
        let tasks = try await loadTasks(configuration: configuration)
        return AgentOSSnapshot(
            projects: projects,
            tasks: tasks
        )
    }

    func syncCodexProjects(
        configuration: AgentOSConfiguration,
        workingDirectories: [URL]
    ) async throws -> AgentOSProjectSyncReport {
        try validate(configuration)
        let directories = workingDirectories
            .filter(\.isFileURL)
            .map(\.standardizedFileURL)
            .reduce(into: [URL]()) { result, url in
                if !result.contains(where: { $0.path == url.path }) { result.append(url) }
            }
        guard !directories.isEmpty else {
            return AgentOSProjectSyncReport(
                applied: true,
                discoveredCount: 0,
                eligibleCount: 0,
                registeredCount: 0,
                enrichedCount: 0,
                refreshedCount: 0,
                preservedCount: 0,
                skippedCount: 0
            )
        }

        let executable = configuration.sourceURL.appendingPathComponent("bin/agent-os")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.launchFailed("Missing executable bin/agent-os under \(configuration.sourceURL.path).")
        }
        var arguments = [
            "sync-codex-projects",
            "--source", configuration.sourceURL.path,
            "--home", configuration.homeURL.path,
            "--apply",
            "--json",
        ]
        for directory in directories {
            arguments.append(contentsOf: ["--directory", directory.path])
        }
        let output = try await ProcessRunner.run(
            executable: executable,
            arguments: arguments,
            currentDirectory: configuration.homeURL
        )
        return try JSONDecoder().decode(AgentOSProjectSyncReport.self, from: output.stdout)
    }

    func createTask(
        configuration: AgentOSConfiguration,
        title: String,
        project: String?,
        goal: String,
        nextAction: String
    ) async throws {
        var arguments = [
            "create",
            "--title", title,
            "--kind", "delivery",
            "--status", "planned",
            "--goal", goal,
            "--summary", "Created in Agent OS.",
            "--next-action", nextAction,
        ]
        if let project, !project.isEmpty {
            arguments.append(contentsOf: ["--project", project])
        }
        _ = try await runTaskBoard(configuration: configuration, arguments: arguments)
    }

    func updateStatus(configuration: AgentOSConfiguration, taskID: String, status: TaskStatus) async throws {
        try validateTaskID(taskID)
        _ = try await runTaskBoard(
            configuration: configuration,
            arguments: ["update", taskID, "--status", status.rawValue]
        )
    }

    func updateCompletionFollowUp(
        configuration: AgentOSConfiguration,
        taskID: String,
        status: AgentOSCompletionFollowUpStatus
    ) async throws {
        try validateTaskID(taskID)
        _ = try await runTaskBoard(
            configuration: configuration,
            arguments: ["completion", taskID, "--follow-up-status", status.rawValue]
        )
    }

    func attachCodex(
        configuration: AgentOSConfiguration,
        taskID: String,
        threadID: String,
        project: String,
        title: String,
        status: String = "active"
    ) async throws {
        try validateTaskID(taskID)
        _ = try await runTaskBoard(
            configuration: configuration,
            arguments: [
                "codex", taskID,
                "--thread-id", threadID,
                "--role", "implementation",
                "--status", status,
                "--origin", "new",
                "--project", project,
                "--title", title,
            ]
        )
    }

    func updateAgentOS(configuration: AgentOSConfiguration, apply: Bool) async throws -> AgentOSUpdateStatus {
        let executable = configuration.sourceURL.appendingPathComponent("bin/agent-os")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.launchFailed("Missing executable bin/agent-os under \(configuration.sourceURL.path).")
        }

        var arguments = ["update", "--source", configuration.sourceURL.path, "--json"]
        if apply { arguments.append("--apply") }
        var environment = ProcessInfo.processInfo.environment
        environment["AGENT_OS_SOURCE_ROOT"] = configuration.sourceURL.path
        environment["AGENT_OS_HOME"] = configuration.homeURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            existingPath,
        ].joined(separator: ":")
        let output = try await ProcessRunner.run(
            executable: executable,
            arguments: arguments,
            currentDirectory: configuration.sourceURL,
            environment: environment
        )
        return try JSONDecoder().decode(AgentOSUpdateStatus.self, from: output.stdout)
    }

    private func loadProjects(home: URL) async throws -> [AgentOSProject] {
        let registry = home.appendingPathComponent("config/projects.yaml")
        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/ruby"),
            arguments: ["-ryaml", "-rjson", "-e", Self.projectRegistryScript, registry.path],
            currentDirectory: home
        )
        return try JSONDecoder().decode([AgentOSProject].self, from: output.stdout)
    }

    private func loadTasks(configuration: AgentOSConfiguration) async throws -> [AgentOSTask] {
        let output = try await runTaskBoard(configuration: configuration, arguments: ["list", "--json"])
        return try JSONDecoder().decode([AgentOSTask].self, from: output)
    }

    private func runTaskBoard(configuration: AgentOSConfiguration, arguments: [String]) async throws -> Data {
        try validate(configuration)
        let executable = configuration.sourceURL.appendingPathComponent("tools/task-board")
        let taskRoot = configuration.homeURL.appendingPathComponent("work", isDirectory: true)
        let output = try await ProcessRunner.run(
            executable: executable,
            arguments: arguments + ["--root", taskRoot.path],
            currentDirectory: configuration.homeURL
        )
        return output.stdout
    }

    private func validate(_ configuration: AgentOSConfiguration) throws {
        let source = configuration.sourceURL
        let home = configuration.homeURL
        guard source.isFileURL, source.path != "/", home.isFileURL, home.path != "/" else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard FileManager.default.fileExists(atPath: home.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard FileManager.default.isExecutableFile(atPath: source.appendingPathComponent("tools/task-board").path) else {
            throw ProcessRunnerError.launchFailed("Missing executable tools/task-board under \(source.path).")
        }
        guard FileManager.default.fileExists(atPath: home.appendingPathComponent("config/projects.yaml").path) else {
            throw ProcessRunnerError.launchFailed("Missing config/projects.yaml under \(home.path).")
        }
    }

    private func validateTaskID(_ taskID: String) throws {
        let pattern = /^[A-Za-z0-9][A-Za-z0-9_-]*$/
        guard taskID.wholeMatch(of: pattern) != nil else {
            throw ProcessRunnerError.launchFailed("Invalid task ID.")
        }
    }
}
