import Foundation
import XCTest
@testable import AgentOS

final class AgentOSTests: XCTestCase {
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

    func testProcessRunnerUsesArgumentVector() async throws {
        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%s", "hello agent-os"]
        )

        XCTAssertEqual(String(decoding: output.stdout, as: UTF8.self), "hello agent-os")
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
}
