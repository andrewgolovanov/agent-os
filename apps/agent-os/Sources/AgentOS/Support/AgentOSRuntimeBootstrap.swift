import Foundation

enum AgentOSRuntimeBootstrap {
    static func prepare(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundledRuntimeURL: URL? = Bundle.main.resourceURL?
            .appendingPathComponent("AgentOSRuntime", isDirectory: true),
        userHomeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AgentOSConfiguration {
        let current = AgentOSConfiguration.current(
            environment: environment,
            userHomeURL: userHomeURL
        )
        guard let runtime = validRuntime(bundledRuntimeURL) else { return current }

        let executable = runtime.appendingPathComponent("bin/agent-os", isDirectory: false)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby", isDirectory: false)
        process.arguments = [
            executable.path,
            "bootstrap",
            "--source", runtime.path,
            "--home", current.homeURL.path,
            "--apply",
            "--json",
        ]
        process.currentDirectoryURL = runtime
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return current
        }
        guard process.terminationStatus == 0 else { return current }

        return AgentOSConfiguration.current(
            environment: environment,
            userHomeURL: userHomeURL
        )
    }

    private static func validRuntime(_ candidate: URL?) -> URL? {
        guard let candidate, candidate.isFileURL, candidate.path != "/" else { return nil }
        let fileManager = FileManager.default
        let cli = candidate.appendingPathComponent("bin/agent-os", isDirectory: false)
        let taskBoard = candidate.appendingPathComponent("tools/task-board", isDirectory: false)
        guard fileManager.fileExists(atPath: cli.path),
              fileManager.isExecutableFile(atPath: taskBoard.path)
        else {
            return nil
        }
        return candidate.resolvingSymlinksInPath().standardizedFileURL
    }
}
