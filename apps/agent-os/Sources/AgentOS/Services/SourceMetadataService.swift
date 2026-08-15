import Foundation

struct SourceMetadataService: Sendable {
    func load(for items: [AgentOSSourceItem]) async -> [String: AgentOSSourceMetadata] {
        await withTaskGroup(of: (String, AgentOSSourceMetadata)?.self) { group in
            for item in items where item.kind == .pullRequest {
                group.addTask {
                    guard let metadata = await loadPullRequest(item) else { return nil }
                    return (item.id, metadata)
                }
            }

            var result: [String: AgentOSSourceMetadata] = [:]
            for await entry in group {
                guard let entry else { continue }
                result[entry.0] = entry.1
            }
            return result
        }
    }

    private func loadPullRequest(_ item: AgentOSSourceItem) async -> AgentOSSourceMetadata? {
        guard let url = URL(string: item.link.url), let ghURL = Self.githubCLIURL() else { return nil }
        do {
            let output = try await ProcessRunner.run(
                executable: ghURL,
                arguments: [
                    "pr", "view", item.link.url,
                    "--json", "number,title,state,isDraft,mergedAt,reviewDecision,headRefName,baseRefName",
                ]
            )
            let payload = try JSONDecoder().decode(GitHubPullRequestPayload.self, from: output.stdout)
            return AgentOSSourcePresentation.pullRequestMetadata(payload: payload, url: url)
        } catch {
            return nil
        }
    }

    static func githubCLICandidates(environment: [String: String] = ProcessInfo.processInfo.environment) -> [String] {
        let pathCandidates = environment["PATH", default: ""]
            .split(separator: ":")
            .map { String($0) + "/gh" }
        return pathCandidates + [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ]
    }

    private static func githubCLIURL() -> URL? {
        githubCLICandidates().first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0) }
    }
}
