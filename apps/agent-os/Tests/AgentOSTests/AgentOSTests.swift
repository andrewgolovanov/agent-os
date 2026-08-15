import Foundation
import SwiftUI
import XCTest
@testable import AgentOS

final class AgentOSTests: XCTestCase {
    func testAgentOSDeepLinksResolveSupportedDestinations() throws {
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://board"))),
            .board
        )
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://focus"))),
            .focus
        )
        XCTAssertNil(AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "https://example.com/board"))))
        XCTAssertNil(AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://unknown"))))
    }

    func testTaskDecodesCanonicalSnakeCaseFields() throws {
        let data = Data(#"""
        {
          "id": "20260814-example",
          "title": "Example",
          "projects": ["example-site"],
          "kind": "delivery",
          "status": "active",
          "goal": "Ship a useful result",
          "summary": "In progress",
          "constraints": [],
          "next_action": "Run verification",
          "waiting_on": null,
          "sources": {
            "slack_threads": [],
            "pull_requests": [],
            "figma": [],
            "deployments": [],
            "other": []
          },
          "codex_threads": [],
          "activity": {"total_seconds": 90, "turns": []},
          "created_at": "2026-08-14T00:00:00Z",
          "updated_at": "2026-08-14T00:01:00Z"
        }
        """#.utf8)

        let task = try JSONDecoder().decode(AgentOSTask.self, from: data)

        XCTAssertEqual(task.status, .active)
        XCTAssertEqual(task.nextAction, "Run verification")
        XCTAssertEqual(task.activity.totalSeconds, 90)
        XCTAssertTrue(task.status.isUnfinished)
    }

    func testTaskDefaultsMissingLegacyActivityToZero() throws {
        let data = Data(#"""
        {
          "id": "20260814-legacy",
          "title": "Legacy task",
          "projects": [],
          "kind": "other",
          "status": "cancelled",
          "goal": "Preserve older records",
          "summary": "Complete",
          "constraints": [],
          "next_action": "None",
          "waiting_on": null,
          "sources": {
            "slack_threads": [],
            "pull_requests": [],
            "figma": [],
            "deployments": [],
            "other": []
          },
          "codex_threads": [],
          "created_at": "2026-08-14T00:00:00Z",
          "updated_at": "2026-08-14T00:01:00Z"
        }
        """#.utf8)

        let task = try JSONDecoder().decode(AgentOSTask.self, from: data)

        XCTAssertEqual(task.activity.totalSeconds, 0)
    }

    func testConfigurationHonorsSeparateSourceAndHomeOverrides() {
        let configuration = AgentOSConfiguration.current(
            environment: [
                "AGENT_OS_SOURCE_ROOT": "/tmp/agent-os-source",
                "AGENT_OS_HOME": "/tmp/agent-os-home",
            ]
        )

        XCTAssertEqual(configuration.sourceURL.path, "/tmp/agent-os-source")
        XCTAssertEqual(configuration.homeURL.path, "/tmp/agent-os-home")
    }

    func testLegacyRootRemainsCompatible() {
        let configuration = AgentOSConfiguration.current(
            environment: ["WORKSPACE_CONSOLE_ROOT": "/tmp/legacy-agent-os"]
        )

        XCTAssertEqual(configuration.sourceURL.path, "/tmp/legacy-agent-os")
        XCTAssertEqual(configuration.homeURL.path, "/tmp/legacy-agent-os")
    }

    func testBundledRuntimeBootstrapsAHomeWithoutSourceCheckout() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-os-app-bootstrap-\(UUID().uuidString)", isDirectory: true)
        let privateHome = temporary.appendingPathComponent("private-home", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let appRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let runtime = appRoot
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("plugins/agent-os/runtime", isDirectory: true)
            .standardizedFileURL
        let configuration = AgentOSRuntimeBootstrap.prepare(
            environment: [
                "HOME": temporary.path,
                "AGENT_OS_HOME": privateHome.path,
            ],
            bundledRuntimeURL: runtime,
            userHomeURL: temporary
        )

        XCTAssertEqual(configuration.homeURL.path, privateHome.path)
        XCTAssertEqual(configuration.sourceURL.path, runtime.resolvingSymlinksInPath().path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: privateHome.appendingPathComponent("config/projects.yaml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: privateHome.appendingPathComponent("work/board.json").path))
        XCTAssertEqual(
            try String(contentsOf: privateHome.appendingPathComponent("source-path"), encoding: .utf8),
            "\(runtime.resolvingSymlinksInPath().path)\n"
        )
    }

    func testProcessRunnerUsesArgumentVector() async throws {
        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%s", "hello agent-os"]
        )

        XCTAssertEqual(String(decoding: output.stdout, as: UTF8.self), "hello agent-os")
    }

    func testProcessRunnerInheritsEnvironmentByDefault() async throws {
        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/printenv"),
            arguments: ["HOME"]
        )

        XCTAssertFalse(String(decoding: output.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testUpdateStatusDecodesCoreAndPluginContract() throws {
        let data = Data(#"""
        {
          "schema_version": 1,
          "update_available": true,
          "source": {
            "configured": true,
            "current_version": "0.1.0",
            "latest_version": "0.2.0",
            "update_available": true,
            "action": "fast-forward-to-release"
          },
          "plugin": {
            "configured": true,
            "installed": true,
            "installed_version": "0.1.0",
            "source_version": "0.2.0",
            "refresh_required": true,
            "updated": false,
            "action": "refresh-after-core"
          }
        }
        """#.utf8)

        let status = try JSONDecoder().decode(AgentOSUpdateStatus.self, from: data)

        XCTAssertEqual(status.updateAvailable, true)
        XCTAssertEqual(status.source.latestVersion, "0.2.0")
        XCTAssertEqual(status.plugin.refreshRequired, true)
    }

    func testBoardStatusOrderKeepsSemanticWorkflow() {
        XCTAssertEqual(TaskStatus.boardColumns, [.inbox, .planned, .active, .waiting, .review])
        XCTAssertEqual(Set(TaskStatus.allCases.map(\.systemImage)).count, TaskStatus.allCases.count)
    }

    func testTaskTimeFormatterKeepsBoardLabelsCompactAndVisible() {
        XCTAssertEqual(AgentOSTimeFormatter.compact(seconds: 0), "0 min")
        XCTAssertEqual(AgentOSTimeFormatter.compact(seconds: 14), "<1 min")
        XCTAssertEqual(AgentOSTimeFormatter.compact(seconds: 1_740), "29 min")
        XCTAssertEqual(AgentOSTimeFormatter.compact(seconds: 3_900), "1 hr 5 min")
    }

    func testStatusTintsCommunicateActiveWaitingAndReviewRoles() {
        let environment = EnvironmentValues()
        let active = TaskStatus.active.tint.resolve(in: environment)
        let waiting = TaskStatus.waiting.tint.resolve(in: environment)
        let review = TaskStatus.review.tint.resolve(in: environment)

        XCTAssertGreaterThan(active.green, active.red)
        XCTAssertGreaterThan(active.green, active.blue)
        XCTAssertGreaterThan(waiting.red, waiting.blue)
        XCTAssertGreaterThan(waiting.green, waiting.blue)
        XCTAssertGreaterThan(review.blue, review.red)
        XCTAssertGreaterThan(review.blue, review.green)
    }

    func testInspectorBackdropIsDarkAndTranslucent() {
        let backdrop = AgentOSTheme.inspectorBackdrop.resolve(in: EnvironmentValues())

        XCTAssertEqual(backdrop.red, 0, accuracy: 0.001)
        XCTAssertEqual(backdrop.green, 0, accuracy: 0.001)
        XCTAssertEqual(backdrop.blue, 0, accuracy: 0.001)
        XCTAssertEqual(backdrop.opacity, 0.48, accuracy: 0.001)
    }

    @MainActor
    func testMenuBarBrandImageUsesStandardTemplateGeometry() {
        let image = AgentOSBrandIcon.menuBarImage

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testSourceItemsPreserveCanonicalKinds() throws {
        let data = Data(#"""
        {
          "slack_threads": [{"identity":"provider-thread:C123:1723723200.000000","url":"https://workspace.example.invalid/archives/C123/p1723723200000000"}],
          "pull_requests": [{"identity":"github:owner/repo#42","url":"https://github.com/owner/repo/pull/42"}],
          "figma": [],
          "deployments": [],
          "other": []
        }
        """#.utf8)

        let sources = try JSONDecoder().decode(AgentOSSources.self, from: data)

        XCTAssertEqual(sources.items.map(\.kind), [.slackThread, .pullRequest])
        XCTAssertEqual(sources.items.map(\.id), [
            "slackThread:provider-thread:C123:1723723200.000000",
            "pullRequest:github:owner/repo#42",
        ])
        XCTAssertEqual(sources.pullRequestItems.map(\.id), [
            "pullRequest:github:owner/repo#42",
        ])
        XCTAssertEqual(sources.supportingItems.map(\.id), [
            "slackThread:provider-thread:C123:1723723200.000000",
        ])
    }

    func testSlackSourcePresentationAddsWorkspaceChannelAndDateContext() {
        let item = AgentOSSourceItem(
            link: AgentOSSourceLink(
                identity: "provider-thread:C123:1723723200.000000",
                url: "https://workspace.example.invalid/archives/C123/p1723723200000000"
            ),
            kind: .slackThread
        )

        let metadata = AgentOSSourcePresentation.localMetadata(for: item)

        XCTAssertEqual(metadata.title, "Slack thread")
        XCTAssertTrue(metadata.context.contains("workspace.example.invalid"))
        XCTAssertTrue(metadata.context.contains("channel C123"))
    }

    func testGitHubPullRequestMetadataDistinguishesMergedAndReviewState() throws {
        let data = Data(#"""
        {
          "number": 42,
          "title": "Ship contextual sources",
          "state": "MERGED",
          "isDraft": false,
          "mergedAt": "2026-08-15T10:00:00Z",
          "reviewDecision": "APPROVED",
          "headRefName": "codex/contextual-sources",
          "baseRefName": "main"
        }
        """#.utf8)
        let payload = try JSONDecoder().decode(GitHubPullRequestPayload.self, from: data)
        let metadata = AgentOSSourcePresentation.pullRequestMetadata(
            payload: payload,
            url: URL(string: "https://github.com/owner/repo/pull/42")!
        )

        XCTAssertEqual(metadata.title, "Ship contextual sources")
        XCTAssertEqual(metadata.context, "owner/repo · PR #42 · main ← codex/contextual-sources")
        XCTAssertEqual(metadata.status, "Merged")
        XCTAssertEqual(metadata.statusTone, .merged)
        XCTAssertEqual(metadata.secondaryStatus, "Approved")
        XCTAssertEqual(metadata.secondaryStatusTone, .positive)
    }

    func testGitHubCLIResolutionIncludesHomebrewOutsideGUIPath() {
        let candidates = SourceMetadataService.githubCLICandidates(
            environment: ["PATH": "/usr/bin:/bin"]
        )

        XCTAssertEqual(candidates.prefix(2), ["/usr/bin/gh", "/bin/gh"])
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/gh"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/gh"))
    }

}
