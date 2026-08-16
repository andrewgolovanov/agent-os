# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/agent_os/project_time"

class ProjectTimeTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("agent-os-project-time-")
    @current = File.join(@root, "projects", "phrasso")
    @historical = File.join(@root, "legacy", "phrasso")
    @sessions = File.join(@root, "sessions")
    FileUtils.mkdir_p([@current, @sessions, File.join(@root, "config")])
    File.write(
      File.join(@root, "config", "projects.yaml"),
      <<~YAML
        schema_version: 1
        agent_os:
          timezone: Europe/Madrid
        projects:
          phrasso:
            display_name: Example Site
            root: #{@current}
            repositories:
              - path: #{@current}
            activity:
              historical_paths:
                - #{@historical}
              exclude_threads:
                - id: session-excluded
                  reason: Not project work.
      YAML
    )
    @tracker = AgentOS::ProjectTime.new(agent_os_home: @root)
  end

  def teardown
    FileUtils.remove_entry(@root) if File.exist?(@root)
  end

  def write_session(id:, cwd:, events:, title: "Implement example feature")
    path = File.join(@sessions, "#{id}.jsonl")
    rows = [
      { "timestamp" => events.first.fetch(:at), "type" => "session_meta", "payload" => { "id" => id, "cwd" => cwd, "timestamp" => events.first.fetch(:at) } },
      { "timestamp" => events.first.fetch(:at), "type" => "event_msg", "payload" => { "type" => "user_message", "message" => title } }
    ]
    events.each do |event|
      rows << {
        "timestamp" => event.fetch(:at),
        "type" => "event_msg",
        "payload" => { "type" => event.fetch(:type), "turn_id" => event.fetch(:turn) }
      }
    end
    File.write(path, rows.map { |row| JSON.generate(row) }.join("\n") + "\n")
  end

  def test_refresh_includes_current_and_historical_paths_and_excludes_non_project_thread
    write_session(
      id: "session-current",
      cwd: @current,
      events: [
        { type: "task_started", turn: "turn-1", at: "2026-07-31T21:59:00Z" },
        { type: "task_complete", turn: "turn-1", at: "2026-07-31T22:01:00Z" }
      ]
    )
    write_session(
      id: "session-history",
      cwd: @historical,
      events: [
        { type: "task_started", turn: "turn-2", at: "2026-08-01T10:00:00Z" },
        { type: "turn_aborted", turn: "turn-2", at: "2026-08-01T10:02:00Z" }
      ]
    )
    write_session(
      id: "session-excluded",
      cwd: @current,
      events: [
        { type: "task_started", turn: "turn-3", at: "2026-08-01T11:00:00Z" },
        { type: "task_complete", turn: "turn-3", at: "2026-08-01T12:00:00Z" }
      ]
    )

    report = @tracker.refresh(project_key: "phrasso", session_roots: [@sessions], at: "2026-08-02T00:00:00Z")

    assert_equal 2, report.dig("summary", "thread_count")
    assert_equal 240, report.dig("summary", "total_seconds")
    assert_equal %w[2026-07 2026-08], report.dig("summary", "months").map { |month| month["month"] }
    assert_equal [60, 180], report.dig("summary", "months").map { |month| month["seconds"] }
    assert_empty @tracker.validate(project_key: "phrasso")
  end

  def test_hook_tracks_unclaimed_project_turn_idempotently
    payload = { "cwd" => @current, "session_id" => "session-hook", "turn_id" => "turn-hook" }

    @tracker.start(payload, at: "2026-08-02T10:00:00Z")
    @tracker.start(payload, at: "2026-08-02T10:00:01Z")
    @tracker.stop(payload, at: "2026-08-02T10:05:00Z")
    @tracker.stop(payload, at: "2026-08-02T10:06:00Z")

    report = @tracker.report("phrasso")
    assert_equal 300, report.dig("summary", "total_seconds")
    assert_equal 1, report.dig("summary", "completed_turns")
    assert_equal 1, report.dig("summary", "thread_count")
    assert_empty @tracker.validate(project_key: "phrasso")
  end

  def test_refresh_deduplicates_repeated_session_events
    write_session(
      id: "session-current",
      cwd: @current,
      events: [
        { type: "task_started", turn: "turn-1", at: "2026-08-02T10:00:00Z" },
        { type: "task_started", turn: "turn-1", at: "2026-08-02T10:00:00Z" },
        { type: "task_complete", turn: "turn-1", at: "2026-08-02T10:01:00Z" },
        { type: "task_complete", turn: "turn-1", at: "2026-08-02T10:01:00Z" }
      ]
    )

    report = @tracker.refresh(project_key: "phrasso", session_roots: [@sessions])

    assert_equal 60, report.dig("summary", "total_seconds")
    assert_equal 1, report.dig("summary", "completed_turns")
  end

  def test_turn_crossing_local_month_boundary_is_split_between_months
    payload = { "cwd" => @current, "session_id" => "session-hook", "turn_id" => "turn-hook" }

    @tracker.start(payload, at: "2026-07-31T21:59:00Z")
    @tracker.stop(payload, at: "2026-07-31T22:01:00Z")

    report = @tracker.report("phrasso")
    assert_equal [60, 60], report.dig("summary", "months").map { |month| month["seconds"] }
    assert_equal %w[2026-07 2026-08], report.dig("summary", "months").map { |month| month["month"] }
  end
end
