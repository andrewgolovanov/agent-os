# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/agent_os/slack_state"

class SlackStateTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-slack-state-")
    @state = AgentOS::SlackState.new(@temporary)
    @state.initialize_store
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_exact_event_deduplication
    event = {
      "channel_id" => "C123",
      "thread_ts" => "1786101301.222869",
      "message_ts" => "1786101400.000001",
      "exact_permalink" => "https://example.slack.com/archives/C123/p1786101400000001",
      "disposition" => "actionable",
      "project" => "phrasso",
      "task_id" => "task_test"
    }

    assert @state.record_seen(event)
    refute @state.record_seen(event)
    assert_equal 1, @state.status.fetch("seen_count")
    assert_empty @state.validate!
  end

  def test_partial_watch_read_does_not_advance_cursor
    @state.watch(channel_id: "C123", thread_ts: "100.000001", reason: "Open task", task_id: "task_test")

    assert_raises(ArgumentError) do
      @state.advance_watch(
        channel_id: "C123",
        thread_ts: "100.000001",
        last_seen_message_ts: "200.000002",
        complete: false
      )
    end
    watch = @state.status.dig("watches", "watches", 0)
    assert_equal "100.000001", watch.fetch("last_seen_message_ts")

    closed = @state.close_watch(channel_id: "C123", thread_ts: "100.000001")
    assert_equal "closed", closed.fetch("state")
  end

  def test_failure_preserves_last_successful_cursor_and_recovery_resets_outage
    @state.monitor_success(cursor: "100.000001", complete: true)
    @state.monitor_failure(code: "slack_unavailable")
    failed = @state.status.fetch("monitor")
    assert_equal "100.000001", failed.fetch("last_successful_cursor")
    assert_equal 1, failed.fetch("consecutive_failures")

    recovered = @state.monitor_success(cursor: "200.000002", complete: true)
    assert recovered.fetch("recovered")
    assert_equal 0, recovered.fetch("consecutive_failures")
    assert_equal "200.000002", recovered.fetch("last_successful_cursor")
  end

  def test_channel_cursors_advance_independently_only_after_complete_reads
    assert_raises(ArgumentError) do
      @state.advance_channel(channel_id: "C123", cursor: "100.000001", complete: false)
    end

    first = @state.advance_channel(channel_id: "C123", cursor: "100.000001", complete: true)
    second = @state.advance_channel(channel_id: "G456", cursor: "200.000002", complete: true)

    assert_nil first.fetch("previous_cursor")
    assert_equal "200.000002", second.fetch("cursor")
    assert_equal(
      { "C123" => "100.000001", "G456" => "200.000002" },
      @state.status.dig("monitor", "channel_cursors")
    )
    assert_empty @state.validate!
  end

  def test_channel_cursor_cannot_move_backwards
    @state.advance_channel(channel_id: "C123", cursor: "200.000002", complete: true)

    error = assert_raises(ArgumentError) do
      @state.advance_channel(channel_id: "C123", cursor: "100.000001", complete: true)
    end

    assert_match(/backwards/, error.message)
    assert_equal "200.000002", @state.status.dig("monitor", "channel_cursors", "C123")
  end

  def test_seen_ledger_rejects_raw_message_content
    error = assert_raises(ArgumentError) do
      @state.record_seen(
        "channel_id" => "C123",
        "thread_ts" => "100.000001",
        "message_ts" => "100.000002",
        "exact_permalink" => "https://example.slack.com/archives/C123/p100000002",
        "disposition" => "fyi",
        "message_text" => "This must not be persisted"
      )
    end
    assert_match(/forbidden/, error.message)
  end
end
