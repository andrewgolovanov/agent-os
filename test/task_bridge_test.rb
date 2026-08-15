# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/agent_os/task_bridge"

class TaskBridgeTest < Minitest::Test
  FIGMA_URL = "https://www.figma.com/design/exampleFileKey123/Example-Website?node-id=42-7"

  def setup
    @root = Dir.mktmpdir("agent-os-task-bridge-")
    @project_root = File.join(@root, "projects", "phrasso")
    @board_root = File.join(@root, "work")
    @runtime_root = File.join(@root, ".runtime", "task-bridge")
    FileUtils.mkdir_p([@project_root, File.join(@root, "config")])
    File.write(
      File.join(@root, "config", "projects.yaml"),
      <<~YAML
        schema_version: 1
        projects:
          phrasso:
            wrapper: #{@project_root}
            repositories:
              - id: site
                path: #{@project_root}
      YAML
    )
    File.write(
      File.join(@root, "config", "task-bridge.yaml"),
      <<~YAML
        schema_version: 1
        defaults:
          enabled: true
          auto_claim: exact_sources
          require_checkpoint: true
          max_candidates: 5
          idle_timeout_minutes: 30
        projects:
          phrasso: {}
      YAML
    )
    @board = AgentOS::TaskBoard.new(@board_root)
    @board.initialize_store
    @bridge = AgentOS::TaskBridge.new(
      agent_os_home: @root,
      board_root: @board_root,
      runtime_root: @runtime_root
    )
  end

  def teardown
    FileUtils.remove_entry(@root) if File.exist?(@root)
  end

  def create_task(id: "task_contact", source: true)
    @board.create(
      "id" => id,
      "title" => "Apply updated contact form design",
      "projects" => ["phrasso"],
      "kind" => "delivery",
      "status" => "inbox",
      "goal" => "Apply the verified Figma design.",
      "summary" => "Ready for implementation.",
      "next_action" => "Inspect the exact Figma node."
    )
    @board.attach_source(id, kind: "figma", value: FIGMA_URL) if source
  end

  def prompt_payload(session: "session-123", turn: "turn-456", prompt: FIGMA_URL)
    {
      "hook_event_name" => "UserPromptSubmit",
      "session_id" => session,
      "turn_id" => turn,
      "cwd" => @project_root,
      "prompt" => prompt
    }
  end

  def test_exact_figma_node_claims_task_and_records_completed_turn
    create_task
    prompt = "Implement #{FIGMA_URL}&m=dev without changing unrelated files"

    result = @bridge.handle_prompt(prompt_payload(prompt: prompt), at: "2026-08-10T10:00:00Z")
    context = result.dig("hookSpecificOutput", "additionalContext")

    assert_includes context, "Task ID: task_contact"
    task = @board.read_task("task_contact")
    assert_equal "active", task.fetch("status")
    assert_equal "session-123", task.dig("codex_threads", 0, "thread_id")
    assert_equal "active", task.dig("codex_threads", 0, "status")

    runtime = File.read(File.join(@runtime_root, "sessions", "session-123", "turns", "turn-456.json"))
    refute_includes runtime, "Implement"
    assert_includes runtime, "prompt_sha256"

    assert_equal({ "continue" => true }, @bridge.handle_stop(prompt_payload, at: "2026-08-10T10:02:00Z"))
    task = @board.read_task("task_contact")
    assert_equal 120, task.dig("activity", "total_seconds")
    assert_equal "idle", task.dig("codex_threads", 0, "status")
    assert_empty @board.validate!
  end

  def test_semantic_similarity_only_suggests_and_does_not_claim
    create_task(source: false)

    result = @bridge.handle_prompt(
      prompt_payload(prompt: "Please update the contact form design"),
      at: "2026-08-10T10:00:00Z"
    )
    context = result.dig("hookSpecificOutput", "additionalContext")

    assert_includes context, "No single exact task match was found."
    assert_includes context, "task_contact"
    assert_empty @board.read_task("task_contact").fetch("codex_threads")
    assert_equal "inbox", @board.read_task("task_contact").fetch("status")
  end

  def test_manual_claim_backfills_a_turn_that_stopped_while_unbound
    create_task(source: false)
    payload = prompt_payload(prompt: "Work on a new outcome")
    @bridge.handle_prompt(payload, at: "2026-08-10T10:00:00Z")
    @bridge.handle_stop(payload, at: "2026-08-10T10:03:00Z")

    task = @bridge.claim(
      "task_contact",
      session_id: "session-123",
      turn_id: "turn-456",
      project_key: "phrasso"
    )

    assert_equal 180, task.dig("activity", "total_seconds")
    assert_equal "idle", task.dig("codex_threads", 0, "status")
  end

  def test_material_changes_require_checkpoint_before_stop
    create_task
    payload = prompt_payload
    @bridge.handle_prompt(payload, at: "2026-08-10T10:00:00Z")
    @bridge.mark_material(payload.merge("tool_name" => "apply_patch"), at: "2026-08-10T10:01:00Z")

    blocked = @bridge.handle_stop(payload, at: "2026-08-10T10:02:00Z")
    assert_equal "block", blocked.fetch("decision")
    assert_includes blocked.fetch("reason"), "task-bridge checkpoint task_contact"

    @bridge.checkpoint(
      "task_contact",
      session_id: "session-123",
      turn_id: "turn-456",
      summary: "Implementation and focused tests are complete.",
      next_action: "Ask the user to verify the form.",
      status: "review"
    )
    assert_equal({ "continue" => true }, @bridge.handle_stop(payload, at: "2026-08-10T10:02:01Z"))
    assert_equal "review", @board.read_task("task_contact").fetch("status")
  end

  def test_reconcile_caps_an_orphaned_turn_at_idle_timeout
    create_task
    @bridge.handle_prompt(prompt_payload, at: "2026-08-10T10:00:00Z")

    closed = @bridge.reconcile_stale(now: "2026-08-10T10:31:00Z")

    assert_equal ["codex:session-123:turn-456"], closed
    task = @board.read_task("task_contact")
    assert_equal 1800, task.dig("activity", "total_seconds")
    assert_equal "2026-08-10T10:30:00.000000Z", task.dig("activity", "turns", 0, "stopped_at")
  end

  def test_next_turn_in_same_session_closes_lost_predecessor_with_cap
    create_task
    @bridge.handle_prompt(prompt_payload(turn: "turn-old"), at: "2026-08-10T10:00:00Z")

    @bridge.handle_prompt(prompt_payload(turn: "turn-new"), at: "2026-08-10T10:40:00Z")

    task = @board.read_task("task_contact")
    old_turn = task.fetch("activity").fetch("turns").find { |turn| turn["turn_id"] == "turn-old" }
    assert_equal 1800, old_turn.fetch("duration_seconds")
    assert_equal "2026-08-10T10:30:00.000000Z", old_turn.fetch("stopped_at")
    assert_equal 1, task.fetch("activity").fetch("turns").count { |turn| turn["stopped_at"].nil? }
  end

  def test_generic_url_is_not_an_exact_auto_claim_source
    create_task(source: false)
    @board.attach_source("task_contact", kind: "deployments", value: "https://preview.example.com/build-42")

    result = @bridge.handle_prompt(
      prompt_payload(prompt: "Check https://preview.example.com/build-42"),
      at: "2026-08-10T10:00:00Z"
    )

    assert_includes result.dig("hookSpecificOutput", "additionalContext"), "No single exact task match was found."
    assert_empty @board.read_task("task_contact").fetch("codex_threads")
  end

  def test_unregistered_project_chat_is_ignored_without_runtime_state
    create_task
    payload = prompt_payload.merge("cwd" => File.join(@root, "elsewhere"))

    assert_nil @bridge.handle_prompt(payload, at: "2026-08-10T10:00:00Z")
    refute File.exist?(@runtime_root)
    assert_empty @board.read_task("task_contact").fetch("codex_threads")
  end

  def test_archived_mixed_history_chat_never_reactivates_task
    create_task
    @board.attach_codex(
      "task_contact",
      thread_id: "session-123",
      role: "implementation",
      status: "archived",
      origin: "new",
      project: "phrasso"
    )

    result = @bridge.handle_prompt(
      prompt_payload(prompt: "Start an unrelated navigation task"),
      at: "2026-08-10T10:00:00Z"
    )

    context = result.dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "legacy Codex task is archived"
    assert_includes @bridge.context(session_id: "session-123"), "legacy Codex task is archived"
    assert_equal "inbox", @board.read_task("task_contact").fetch("status")
    assert_equal "archived", @board.read_task("task_contact").dig("codex_threads", 0, "status")
    assert_empty @board.read_task("task_contact").fetch("activity").fetch("turns")
  end
end
