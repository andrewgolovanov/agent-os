import Foundation
import SwiftUI
import XCTest
@testable import AgentOS

final class AgentOSTests: XCTestCase {
    func testProjectSyncReportDecodesRuntimeCounts() throws {
        let data = Data(#"""
        {
          "applied": true,
          "discovered_count": 12,
          "eligible_count": 8,
          "registered_count": 3,
          "preserved_count": 5,
          "skipped_count": 4
        }
        """#.utf8)

        let report = try JSONDecoder().decode(AgentOSProjectSyncReport.self, from: data)

        XCTAssertTrue(report.applied)
        XCTAssertEqual(report.discoveredCount, 12)
        XCTAssertEqual(report.eligibleCount, 8)
        XCTAssertEqual(report.registeredCount, 3)
        XCTAssertEqual(report.preservedCount, 5)
        XCTAssertEqual(report.skippedCount, 4)
    }

    func testAppearanceDefaultsToDarkAndSupportsPersistentToggle() {
        XCTAssertEqual(AgentOSAppearance.resolved(arguments: [], storedValue: "invalid"), .dark)
        XCTAssertEqual(AgentOSAppearance.resolved(arguments: [], storedValue: "light"), .light)
        XCTAssertEqual(AgentOSAppearance.dark.toggled, .light)
        XCTAssertEqual(AgentOSAppearance.light.toggled, .dark)
        XCTAssertEqual(AgentOSAppearance.dark.toggleLabel, "Use light appearance")
        XCTAssertEqual(AgentOSAppearance.light.toggleSystemImage, "moon")
        XCTAssertEqual(
            AgentOSAppearance.resolved(arguments: ["--force-light-appearance"], storedValue: "dark"),
            .light
        )
        XCTAssertEqual(
            AgentOSAppearance.resolved(arguments: ["--force-dark-appearance"], storedValue: "light"),
            .dark
        )
    }

    func testShadcnNeutralSemanticTokensAdaptToLightAndDarkSchemes() {
        var lightEnvironment = EnvironmentValues()
        lightEnvironment.colorScheme = .light
        var darkEnvironment = EnvironmentValues()
        darkEnvironment.colorScheme = .dark

        let lightBackground = AgentOSTheme.background.resolve(in: lightEnvironment)
        let darkBackground = AgentOSTheme.background.resolve(in: darkEnvironment)
        let lightForeground = AgentOSTheme.foreground.resolve(in: lightEnvironment)
        let darkForeground = AgentOSTheme.foreground.resolve(in: darkEnvironment)
        let lightSidebar = AgentOSTheme.sidebar.resolve(in: lightEnvironment)
        let darkSidebar = AgentOSTheme.sidebar.resolve(in: darkEnvironment)

        XCTAssertEqual(lightBackground.red, 1, accuracy: 0.001)
        XCTAssertEqual(darkBackground.red, 10.0 / 255, accuracy: 0.001)
        XCTAssertEqual(lightForeground.red, 10.0 / 255, accuracy: 0.001)
        XCTAssertEqual(darkForeground.red, 250.0 / 255, accuracy: 0.001)
        XCTAssertEqual(lightSidebar.red, 250.0 / 255, accuracy: 0.001)
        XCTAssertEqual(darkSidebar.red, 23.0 / 255, accuracy: 0.001)
    }

    func testAgentOSDeepLinksResolveSupportedDestinations() throws {
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://board"))),
            .board
        )
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://focus"))),
            .focus
        )
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://done"))),
            .done
        )
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://time"))),
            .done
        )
        XCTAssertEqual(
            AgentOSDeepLink.destination(for: try XCTUnwrap(URL(string: "agent-os://history"))),
            .done
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
          "labels": [{"key":"slack:C123","name":"#client-checks","kind":"slack_channel"}],
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
          "activity": {
            "total_seconds": 90,
            "turns": [{
              "started_at": "2026-08-14T00:00:00Z",
              "stopped_at": "2026-08-14T00:01:30Z",
              "duration_seconds": 90
            }]
          },
          "created_at": "2026-08-14T00:00:00Z",
          "updated_at": "2026-08-14T00:01:00Z"
        }
        """#.utf8)

        let task = try JSONDecoder().decode(AgentOSTask.self, from: data)

        XCTAssertEqual(task.status, .active)
        XCTAssertEqual(task.labels.first?.key, "slack:C123")
        XCTAssertEqual(task.labels.first?.name, "#client-checks")
        XCTAssertEqual(task.nextAction, "Run verification")
        XCTAssertEqual(task.activity.totalSeconds, 90)
        XCTAssertEqual(task.activity.turns.count, 1)
        XCTAssertEqual(task.activity.turns.first?.durationSeconds, 90)
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
        XCTAssertTrue(task.labels.isEmpty)
        XCTAssertEqual(task.completionFollowUpStatus, .notRequired)
    }

    func testProjectSlackMappingsHideOnlyRedundantSidebarLabels() throws {
        let mappedProjectData = Data(#"""
        {
          "key": "sample-product",
          "displayName": "Sample Product",
          "status": "active",
          "root": "/tmp/sample-product",
          "slackChannels": [
            {"id":"CEXAMPLE","name":"#project-sample-product-int"}
          ],
          "repositories": [{
            "id": "site",
            "path": "/tmp/sample-product",
            "role": "primary",
            "sourceOfTruth": "unknown",
            "primaryBranch": "main"
          }]
        }
        """#.utf8)
        let legacyProjectData = Data(#"""
        {
          "key": "legacy",
          "displayName": "Legacy",
          "status": "active",
          "root": "/tmp/legacy",
          "repositories": [{
            "id": "legacy",
            "path": "/tmp/legacy",
            "role": "primary",
            "sourceOfTruth": "unknown",
            "primaryBranch": "main"
          }]
        }
        """#.utf8)
        let project = try JSONDecoder().decode(AgentOSProject.self, from: mappedProjectData)
        let legacyProject = try JSONDecoder().decode(AgentOSProject.self, from: legacyProjectData)
        let labels = [
            AgentOSLabel(key: "slack:CEXAMPLE", name: "#project-sample-product-int", kind: "slack_channel"),
            AgentOSLabel(key: "slack:CUNMAPPED", name: "#general-checks", kind: "slack_channel"),
        ]

        XCTAssertEqual(project.slackChannels.first?.labelKey, "slack:CEXAMPLE")
        XCTAssertTrue(legacyProject.slackChannels.isEmpty)
        XCTAssertEqual(
            SidebarView.visibleLabels(projects: [project, legacyProject], labels: labels).map(\.key),
            ["slack:CUNMAPPED"]
        )
        XCTAssertEqual(labels.map(\.name), ["#project-sample-product-int", "#general-checks"])
    }

    func testLocalOnlyProjectDecodesWithoutRepositories() throws {
        let data = Data(#"""
        {
          "key": "local-only",
          "displayName": "Local Only",
          "status": "active",
          "root": "/tmp/local-only"
        }
        """#.utf8)

        let project = try JSONDecoder().decode(AgentOSProject.self, from: data)

        XCTAssertEqual(project.key, "local-only")
        XCTAssertEqual(project.preferredWorkingDirectory.path, "/tmp/local-only")
        XCTAssertTrue(project.repositories.isEmpty)
        XCTAssertTrue(project.slackChannels.isEmpty)
    }

    func testLegacyProjectSyncReportDefaultsNewLifecycleCounts() throws {
        let data = Data(#"""
        {
          "applied": true,
          "discovered_count": 1,
          "eligible_count": 1,
          "registered_count": 0,
          "preserved_count": 1,
          "skipped_count": 0
        }
        """#.utf8)

        let report = try JSONDecoder().decode(AgentOSProjectSyncReport.self, from: data)

        XCTAssertEqual(report.enrichedCount, 0)
        XCTAssertEqual(report.refreshedCount, 0)
        XCTAssertEqual(report.preservedCount, 1)
    }

    func testInspectorUsesComfortableResizableDesktopWidths() {
        XCTAssertEqual(AgentOSMetrics.inspectorMinWidth, 420)
        XCTAssertEqual(AgentOSMetrics.inspectorIdealWidth, 520)
        XCTAssertEqual(AgentOSMetrics.inspectorMaxWidth, 680)
        XCTAssertLessThan(AgentOSMetrics.inspectorMinWidth, AgentOSMetrics.inspectorIdealWidth)
        XCTAssertLessThan(AgentOSMetrics.inspectorIdealWidth, AgentOSMetrics.inspectorMaxWidth)
        XCTAssertEqual(AgentOSMetrics.clampedInspectorWidth(200), 420)
        XCTAssertEqual(AgentOSMetrics.clampedInspectorWidth(560), 560)
        XCTAssertEqual(AgentOSMetrics.clampedInspectorWidth(900), 680)
    }

    func testFocusListUsesReadableTypographyRhythmAndBoundedMeasure() {
        XCTAssertEqual(AgentOSTypography.listTitleSize, 14)
        XCTAssertEqual(AgentOSTypography.listBodySize, 13)
        XCTAssertEqual(AgentOSTypography.listSectionTitleSize, 12)
        XCTAssertEqual(AgentOSTypography.listBodyLineSpacing, 2)
        XCTAssertEqual(AgentOSTypography.listFlow, 6)
        XCTAssertEqual(AgentOSMetrics.focusContentTopPadding, 16)
        XCTAssertEqual(AgentOSMetrics.focusRowHorizontalPadding, 16)
        XCTAssertEqual(AgentOSMetrics.focusRowVerticalPadding, 10)
        XCTAssertEqual(AgentOSMetrics.focusSectionHeaderTopPadding, 10)
        XCTAssertEqual(AgentOSMetrics.focusSectionHeaderBottomPadding, 6)
        XCTAssertEqual(AgentOSMetrics.focusTextMeasure, 880)
    }

    func testFocusDateSectionsUseLocalCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 2 * 60 * 60))
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))
        )

        XCTAssertEqual(
            FocusDateSections.bucket(for: "2026-08-20T08:00:00Z", relativeTo: now, calendar: calendar),
            .today
        )
        XCTAssertEqual(
            FocusDateSections.bucket(for: "2026-08-19T12:00:00Z", relativeTo: now, calendar: calendar),
            .yesterday
        )
        XCTAssertEqual(
            FocusDateSections.bucket(for: "2026-08-18T12:00:00.123Z", relativeTo: now, calendar: calendar),
            .thisWeek
        )
        XCTAssertEqual(
            FocusDateSections.bucket(for: "2026-08-12T12:00:00Z", relativeTo: now, calendar: calendar),
            .lastWeek
        )
        XCTAssertEqual(
            FocusDateSections.bucket(for: "2026-08-01T12:00:00Z", relativeTo: now, calendar: calendar),
            .earlier
        )
        XCTAssertEqual(
            FocusDateSections.bucket(for: "not-a-date", relativeTo: now, calendar: calendar),
            .earlier
        )
        XCTAssertEqual(
            FocusDateBucket.allCases.map(\.title),
            ["Today", "Yesterday", "This Week", "Last Week", "Earlier"]
        )
    }

    func testDoneTaskDecodesCompletionFollowUp() throws {
        let data = Data(#"""
        {
          "id": "20260816-complete",
          "title": "Completed task",
          "projects": ["example-site"],
          "kind": "delivery",
          "status": "done",
          "goal": "Preserve the delivery record",
          "summary": "Shipped",
          "constraints": [],
          "next_action": "Notify the source thread",
          "waiting_on": null,
          "sources": {
            "slack_threads": [{"identity":"slack:C123:1723723200.000000","url":"https://workspace.example.invalid/archives/C123/p1723723200000000"}],
            "pull_requests": [],
            "figma": [],
            "deployments": [],
            "other": []
          },
          "codex_threads": [],
          "activity": {"total_seconds": 0, "turns": []},
          "completion": {
            "completed_at": "2026-08-16T12:00:00Z",
            "follow_up_status": "pending",
            "follow_up_sent_at": null
          },
          "created_at": "2026-08-16T11:00:00Z",
          "updated_at": "2026-08-16T12:00:00Z"
        }
        """#.utf8)

        let task = try JSONDecoder().decode(AgentOSTask.self, from: data)

        XCTAssertEqual(task.completedAt, "2026-08-16T12:00:00Z")
        XCTAssertEqual(task.completionFollowUpStatus, .pending)
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

    @MainActor
    func testFileWatcherDeliversBackgroundFileEventsOnMainActor() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-os-file-watcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let change = expectation(description: "file watcher change")
        let watcher = try AgentOSFileWatcher(directory: directory) {
            XCTAssertTrue(Thread.isMainThread)
            change.fulfill()
        }
        let directoryPath = directory.path

        try await Task.detached {
            let file = URL(fileURLWithPath: directoryPath).appendingPathComponent("event.txt")
            try Data("changed".utf8).write(to: file)
        }.value

        await fulfillment(of: [change], timeout: 3)
        withExtendedLifetime(watcher) {}
    }

    func testCodexOpenCompletionResumesFromBackgroundQueue() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion = CodexHandoffService.makeOpenCompletion(continuation: continuation)
            DispatchQueue.global(qos: .utility).async(
                execute: DispatchWorkItem {
                    completion(nil, nil)
                }
            )
        }
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

    func testDonePeriodFiltersByCompletionDate() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: Date())))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        XCTAssertTrue(
            AgentOSDateMath.contains(
                formatter.string(from: now.addingTimeInterval(-3 * 24 * 60 * 60)),
                in: .sevenDays,
                relativeTo: now
            )
        )
        XCTAssertFalse(
            AgentOSDateMath.contains(
                formatter.string(from: now.addingTimeInterval(-10 * 24 * 60 * 60)),
                in: .sevenDays,
                relativeTo: now
            )
        )
        XCTAssertTrue(AgentOSDateMath.contains("invalid", in: .all, relativeTo: now))
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
        XCTAssertNil(sources.slackThreads.first?.title)
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

    func testSlackSourcePresentationUsesStoredRootMessageTitle() throws {
        let data = Data(#"""
        {
          "identity": "provider-thread:C123:1723723200.000000",
          "url": "https://workspace.example.invalid/archives/C123/p1723723200000000",
          "title": "Please verify the client launch checklist"
        }
        """#.utf8)
        let item = AgentOSSourceItem(
            link: try JSONDecoder().decode(AgentOSSourceLink.self, from: data),
            kind: .slackThread
        )

        let metadata = AgentOSSourcePresentation.localMetadata(for: item)

        XCTAssertEqual(metadata.title, "Please verify the client launch checklist")
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
