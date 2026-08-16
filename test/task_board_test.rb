# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../lib/agent_os/task_board"

class TaskBoardTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-task-board-")
    @board = AgentOS::TaskBoard.new(@temporary)
    @board.initialize_store
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def create_task(id: "task_test")
    @board.create(
      "id" => id,
      "title" => "Ship a verified outcome",
      "projects" => ["phrasso"],
      "kind" => "delivery",
      "status" => "inbox",
      "goal" => "Deliver one coherent result.",
      "summary" => "Ready for triage.",
      "next_action" => "Inspect the source context."
    )
  end

  def test_create_source_codex_and_routing_rebuild_board
    create_task
    slack_url = "https://example.slack.com/archives/C0EXAMPLE01/p1786232231519149"
    @board.attach_source("task_test", kind: "slack_threads", value: slack_url)
    @board.attach_codex("task_test", thread_id: "thread-123", role: "implementation", origin: "routed")
    routed = @board.add_routing(
      "task_test",
      project: "phrasso",
      role: "implementation",
      reason_code: "saved_project_unknown",
      reason: "Prepare a handoff after the saved project is configured."
    )
    route_id = routed.dig("routing", 0, "id")
    @board.update_routing(
      "task_test",
      route_id: route_id,
      state: "routed",
      attempted: true,
      codex_thread_id: "thread-123"
    )

    task = @board.read_task("task_test")
    assert_equal "slack:C0EXAMPLE01:1786232231.519149", task.dig("sources", "slack_threads", 0, "identity")
    assert_equal "codex://threads/thread-123", task.dig("codex_threads", 0, "url")
    assert_equal "routed", task.dig("routing", 0, "state")
    assert_equal 1, task.dig("routing", 0, "attempts")
    assert_empty @board.validate!
  end

  def test_source_attachment_is_idempotent
    create_task
    url = "https://github.com/example-org/example-site/pull/42"
    2.times { @board.attach_source("task_test", kind: "pull_requests", value: url) }

    assert_equal 1, @board.read_task("task_test").dig("sources", "pull_requests").length
  end

  def test_unassigned_inbox_task_is_valid
    task = @board.create(
      "id" => "task_unassigned",
      "title" => "Clarify an unknown project",
      "kind" => "coordination",
      "status" => "inbox",
      "goal" => "Route the signal to the correct project.",
      "summary" => "The source is actionable but project attribution is unknown.",
      "next_action" => "Ask which project owns the outcome."
    )

    assert_empty task.fetch("projects")
    assert_empty @board.validate!
  end

  def test_pull_request_cannot_belong_to_two_tasks
    create_task
    create_task(id: "task_other")
    url = "https://github.com/example-org/example-site/pull/42"
    @board.attach_source("task_test", kind: "pull_requests", value: url)

    error = assert_raises(ArgumentError) do
      @board.attach_source("task_other", kind: "pull_requests", value: url)
    end
    assert_match(/already belongs/, error.message)
  end

  def test_summary_counts_only_unfinished_tasks
    create_task
    create_task(id: "task_done")
    @board.update("task_done", "status" => "done")
    create_task(id: "task_cancelled")
    @board.update("task_cancelled", "status" => "cancelled")

    summary = @board.summary

    assert_equal 3, summary.fetch("total")
    assert_equal 1, summary.fetch("unfinished_total")
    assert_equal 2, summary.fetch("finished_total")
    assert_equal 1, summary.dig("unfinished_by_status", "inbox")
  end

  def test_done_task_keeps_completion_and_requires_slack_follow_up
    create_task
    @board.attach_source(
      "task_test",
      kind: "slack_threads",
      value: "https://example.slack.com/archives/C0EXAMPLE01/p1786232231519149"
    )

    task = @board.update("task_test", "status" => "done")

    refute_nil task.dig("completion", "completed_at")
    assert_equal "pending", task.dig("completion", "follow_up_status")
    assert_nil task.dig("completion", "follow_up_sent_at")
    assert_empty @board.validate!
  end

  def test_completion_follow_up_can_be_confirmed_and_reopened_task_resets_it
    create_task
    @board.attach_source(
      "task_test",
      kind: "slack_threads",
      value: "https://example.slack.com/archives/C0EXAMPLE01/p1786232231519149"
    )
    @board.update("task_test", "status" => "done")

    task = @board.update_completion("task_test", follow_up_status: "sent")
    assert_equal "sent", task.dig("completion", "follow_up_status")
    refute_nil task.dig("completion", "follow_up_sent_at")

    task = @board.update("task_test", "status" => "active")
    assert_nil task.dig("completion", "completed_at")
    assert_equal "not_required", task.dig("completion", "follow_up_status")
    assert_nil task.dig("completion", "follow_up_sent_at")
    assert_empty @board.validate!
  end

  def test_slack_source_attached_after_completion_reopens_follow_up
    create_task
    task = @board.update("task_test", "status" => "done")
    assert_equal "not_required", task.dig("completion", "follow_up_status")

    task = @board.attach_source(
      "task_test",
      kind: "slack_threads",
      value: "https://example.slack.com/archives/C0EXAMPLE01/p1786232231519149"
    )

    assert_equal "pending", task.dig("completion", "follow_up_status")
    assert_empty @board.validate!
  end

  def test_human_board_is_rebuilt_after_task_mutations
    create_task
    board_path = File.join(@temporary, "BOARD.md")

    dashboard = File.read(board_path)
    assert_includes dashboard, "Невыполнено: **1**"
    assert_includes dashboard, "Ship a verified outcome"
    assert_includes dashboard, "Следующий шаг: Inspect the source context."

    @board.update(
      "task_test",
      "status" => "waiting",
      "summary" => "Implementation is blocked.",
      "next_action" => "Wait for approval.",
      "waiting_on" => "Client approval."
    )

    dashboard = File.read(board_path)
    assert_includes dashboard, "Ожидание (`waiting`) — 1"
    assert_includes dashboard, "Блокировка: Client approval."
    assert_includes dashboard, "items/task_test/STATUS.md"
    assert_empty @board.validate!
  end

  def test_activity_counts_completed_codex_turn_once
    create_task
    @board.attach_codex("task_test", thread_id: "session-123", role: "implementation")

    @board.activity_start(
      "task_test",
      session_id: "session-123",
      turn_id: "turn-456",
      at: "2026-08-10T10:00:00Z"
    )
    assert_equal "active", @board.read_task("task_test").dig("codex_threads", 0, "status")
    2.times do
      @board.activity_stop(
        "task_test",
        session_id: "session-123",
        turn_id: "turn-456",
        at: "2026-08-10T10:02:30Z"
      )
    end

    task = @board.read_task("task_test")
    assert_equal 150, task.dig("activity", "total_seconds")
    assert_equal "idle", task.dig("codex_threads", 0, "status")
    assert_equal 1, task.dig("activity", "turns").length
    assert_equal 150, @board.summary.fetch("tracked_seconds")
    assert_empty @board.validate!
  end

  def test_stopping_an_older_turn_keeps_membership_active_until_latest_turn_stops
    create_task
    @board.attach_codex("task_test", thread_id: "session-123", role: "implementation")
    @board.activity_start("task_test", session_id: "session-123", turn_id: "turn-old", at: "2026-08-10T10:00:00Z")
    @board.activity_start("task_test", session_id: "session-123", turn_id: "turn-current", at: "2026-08-10T10:01:00Z")

    @board.activity_stop("task_test", session_id: "session-123", turn_id: "turn-old", at: "2026-08-10T10:02:00Z")
    assert_equal "active", @board.read_task("task_test").dig("codex_threads", 0, "status")
    assert_equal 1, @board.summary.fetch("active_turns")

    @board.activity_stop("task_test", session_id: "session-123", turn_id: "turn-current", at: "2026-08-10T10:03:00Z")
    assert_equal "idle", @board.read_task("task_test").dig("codex_threads", 0, "status")
    assert_equal 0, @board.summary.fetch("active_turns")
    assert_empty @board.validate!
  end

  def test_codex_task_cannot_belong_to_two_outcomes
    create_task
    create_task(id: "task_other")
    @board.attach_codex("task_test", thread_id: "session-123", role: "implementation")

    error = assert_raises(ArgumentError) do
      @board.attach_codex("task_other", thread_id: "session-123", role: "review")
    end
    assert_match(/already belongs/, error.message)
  end

  def test_activity_hook_records_a_linked_turn_and_ignores_an_unlinked_session
    create_task
    @board.attach_codex("task_test", thread_id: "session-123", role: "implementation")
    hook = File.expand_path("../tools/codex-activity-hook", __dir__)
    environment = {
      "AGENT_OS_HOME" => @temporary,
      "AGENT_OS_TASK_ROOT" => @temporary,
      "AGENT_OS_PROJECTS_CONFIG" => File.expand_path("../config/projects.yaml", __dir__),
      "AGENT_OS_TASK_BRIDGE_CONFIG" => File.expand_path("../config/task-bridge.yaml", __dir__),
      "AGENT_OS_TASK_BRIDGE_RUNTIME" => File.join(@temporary, ".runtime", "task-bridge")
    }

    start_payload = JSON.generate(
      "hook_event_name" => "UserPromptSubmit",
      "session_id" => "session-123",
      "turn_id" => "turn-456"
    )
    _, stderr, status = Open3.capture3(environment, hook, stdin_data: start_payload)
    assert status.success?, stderr

    stop_payload = JSON.generate(
      "hook_event_name" => "Stop",
      "session_id" => "session-123",
      "turn_id" => "turn-456"
    )
    _, stderr, status = Open3.capture3(environment, hook, stdin_data: stop_payload)
    assert status.success?, stderr

    ignored_payload = JSON.generate(
      "hook_event_name" => "UserPromptSubmit",
      "session_id" => "session-unlinked",
      "turn_id" => "turn-other"
    )
    _, stderr, status = Open3.capture3(environment, hook, stdin_data: ignored_payload)
    assert status.success?, stderr

    task = @board.read_task("task_test")
    assert_equal 1, task.dig("activity", "turns").length
    refute_nil task.dig("activity", "turns", 0, "stopped_at")
    assert_empty @board.validate!
  end

  def test_concurrent_creates_keep_a_valid_index
    pids = 6.times.map do |index|
      fork do
        AgentOS::TaskBoard.new(@temporary).create(
          "id" => "task_parallel_#{index}",
          "title" => "Parallel #{index}",
          "projects" => ["phrasso"],
          "kind" => "maintenance",
          "status" => "inbox",
          "goal" => "Exercise the lock.",
          "summary" => "Concurrent fixture.",
          "next_action" => "Validate the board."
        )
        exit! 0
      rescue StandardError
        exit! 1
      end
    end
    statuses = pids.map { |pid| Process.wait2(pid).last }

    assert statuses.all?(&:success?)
    assert_equal 6, @board.tasks.length
    assert_empty @board.validate!
  end
end
