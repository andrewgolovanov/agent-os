# frozen_string_literal: true

require "fileutils"
require "json"
require "securerandom"
require "time"

module AgentOS
  class SlackState
    DISPOSITIONS = %w[actionable update blocker ambiguity fyi duplicate ignored].freeze
    WATCH_STATES = %w[active closed expired].freeze

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    def initialize_store
      FileUtils.mkdir_p(root)
      with_lock do
        atomic_write(watches_path, JSON.pretty_generate(empty_watches) + "\n") unless File.exist?(watches_path)
        atomic_write(monitor_path, JSON.pretty_generate(empty_monitor) + "\n") unless File.exist?(monitor_path)
        FileUtils.touch(seen_path)
      end
    end

    def record_seen(event)
      with_lock do
        initialize_files
        normalized = normalize_event(event)
        identity = event_identity(normalized)
        return false if seen_events.any? { |candidate| event_identity(candidate) == identity }

        File.open(seen_path, "a", 0o600) do |file|
          file.write(JSON.generate(normalized) + "\n")
          file.flush
          file.fsync
        end
        true
      end
    end

    def watch(channel_id:, thread_ts:, reason:, task_id: nil, expires_at: nil)
      with_lock do
        initialize_files
        payload = read_json(watches_path)
        identity = "#{channel_id}:#{thread_ts}"
        entry = payload.fetch("watches").find { |item| item["identity"] == identity }
        now = timestamp
        values = {
          "identity" => identity,
          "channel_id" => channel_id,
          "thread_ts" => thread_ts,
          "last_seen_message_ts" => thread_ts,
          "reason" => reason,
          "task_id" => task_id,
          "state" => "active",
          "expires_at" => expires_at,
          "updated_at" => now
        }
        if entry
          previous_cursor = entry["last_seen_message_ts"]
          entry.merge!(values)
          entry["last_seen_message_ts"] = previous_cursor
        else
          values["created_at"] = now
          payload.fetch("watches") << values
        end
        atomic_write(watches_path, JSON.pretty_generate(payload) + "\n")
        values
      end
    end

    def advance_watch(channel_id:, thread_ts:, last_seen_message_ts:, complete:)
      raise ArgumentError, "refusing to advance watch after a partial read" unless complete

      with_lock do
        initialize_files
        payload = read_json(watches_path)
        identity = "#{channel_id}:#{thread_ts}"
        entry = payload.fetch("watches").find { |item| item["identity"] == identity }
        raise ArgumentError, "unknown watch: #{identity}" unless entry
        raise ArgumentError, "watch is not active: #{identity}" unless entry["state"] == "active"

        entry["last_seen_message_ts"] = last_seen_message_ts
        entry["updated_at"] = timestamp
        atomic_write(watches_path, JSON.pretty_generate(payload) + "\n")
        entry
      end
    end

    def close_watch(channel_id:, thread_ts:, state: "closed")
      raise ArgumentError, "invalid terminal watch state: #{state}" unless %w[closed expired].include?(state)

      with_lock do
        initialize_files
        payload = read_json(watches_path)
        identity = "#{channel_id}:#{thread_ts}"
        entry = payload.fetch("watches").find { |item| item["identity"] == identity }
        raise ArgumentError, "unknown watch: #{identity}" unless entry

        entry["state"] = state
        entry["updated_at"] = timestamp
        atomic_write(watches_path, JSON.pretty_generate(payload) + "\n")
        entry
      end
    end

    def monitor_success(cursor:, complete:)
      raise ArgumentError, "refusing to advance global cursor after a partial scan" unless complete

      with_lock do
        initialize_files
        payload = read_json(monitor_path)
        recovered = payload.fetch("consecutive_failures").positive?
        payload["last_successful_cursor"] = cursor
        payload["last_success_at"] = timestamp
        payload["last_failure_code"] = nil
        payload["consecutive_failures"] = 0
        payload["recovered"] = recovered
        atomic_write(monitor_path, JSON.pretty_generate(payload) + "\n")
        payload
      end
    end

    def monitor_failure(code:)
      with_lock do
        initialize_files
        payload = read_json(monitor_path)
        payload["last_failure_code"] = code
        payload["last_failure_at"] = timestamp
        payload["consecutive_failures"] = payload.fetch("consecutive_failures") + 1
        payload["recovered"] = false
        atomic_write(monitor_path, JSON.pretty_generate(payload) + "\n")
        payload
      end
    end

    def status
      initialize_store
      {
        "seen_count" => seen_events.length,
        "watches" => read_json(watches_path),
        "monitor" => read_json(monitor_path)
      }
    end

    def validate!
      initialize_store
      errors = []
      identities = seen_events.map { |event| event_identity(event) }
      errors << "seen ledger contains duplicate identities" unless identities.uniq.length == identities.length

      seen_events.each_with_index do |event, index|
        allowed = %w[channel_id thread_ts message_ts exact_permalink processed_at disposition project task_id codex_project_id codex_thread_id route_action]
        unknown = event.keys - allowed
        errors << "seen event #{index + 1} contains forbidden fields: #{unknown.join(", ")}" unless unknown.empty?
        errors << "seen event #{index + 1} has invalid disposition" unless DISPOSITIONS.include?(event["disposition"])
      end

      watches = read_json(watches_path)
      errors << "watches schema_version must be 1" unless watches["schema_version"] == 1
      Array(watches["watches"]).each do |watch|
        errors << "watch has invalid state: #{watch["identity"]}" unless WATCH_STATES.include?(watch["state"])
      end

      monitor = read_json(monitor_path)
      errors << "monitor schema_version must be 1" unless monitor["schema_version"] == 1
      errors << "monitor consecutive_failures must be non-negative" unless monitor["consecutive_failures"].is_a?(Integer) && monitor["consecutive_failures"] >= 0
      errors
    rescue JSON::ParserError => e
      ["invalid runtime JSON: #{e.message}"]
    end

    private

    def seen_path
      File.join(root, "slack-seen.jsonl")
    end

    def watches_path
      File.join(root, "slack-thread-watches.json")
    end

    def monitor_path
      File.join(root, "slack-monitor.json")
    end

    def lock_path
      File.join(root, ".lock")
    end

    def initialize_files
      FileUtils.mkdir_p(root)
      FileUtils.touch(seen_path)
      atomic_write(watches_path, JSON.pretty_generate(empty_watches) + "\n") unless File.exist?(watches_path)
      atomic_write(monitor_path, JSON.pretty_generate(empty_monitor) + "\n") unless File.exist?(monitor_path)
    end

    def empty_watches
      { "schema_version" => 1, "watches" => [] }
    end

    def empty_monitor
      {
        "schema_version" => 1,
        "last_successful_cursor" => nil,
        "last_success_at" => nil,
        "last_failure_code" => nil,
        "last_failure_at" => nil,
        "consecutive_failures" => 0,
        "recovered" => false
      }
    end

    def normalize_event(event)
      required = %w[channel_id thread_ts message_ts exact_permalink disposition]
      missing = required.select { |field| event[field].to_s.strip.empty? }
      raise ArgumentError, "missing seen fields: #{missing.join(", ")}" unless missing.empty?
      raise ArgumentError, "invalid disposition: #{event["disposition"]}" unless DISPOSITIONS.include?(event["disposition"])

      allowed = %w[channel_id thread_ts message_ts exact_permalink disposition project task_id codex_project_id codex_thread_id route_action]
      unknown = event.keys - allowed
      raise ArgumentError, "forbidden seen fields: #{unknown.join(", ")}" unless unknown.empty?

      event.merge("processed_at" => timestamp).reject { |_, value| value.nil? || value == "" }
    end

    def event_identity(event)
      [event.fetch("channel_id"), event.fetch("thread_ts"), event.fetch("message_ts")].join(":")
    end

    def seen_events
      return [] unless File.file?(seen_path)

      File.readlines(seen_path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
    end

    def read_json(path)
      JSON.parse(File.read(path))
    end

    def timestamp
      Time.now.utc.iso8601(6)
    end

    def with_lock
      FileUtils.mkdir_p(root)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock.flock(File::LOCK_UN) rescue nil
      end
    end

    def atomic_write(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      temporary = "#{path}.tmp-#{Process.pid}-#{SecureRandom.hex(4)}"
      File.open(temporary, "w", 0o600) do |file|
        file.write(content)
        file.flush
        file.fsync
      end
      File.rename(temporary, path)
    ensure
      File.delete(temporary) if defined?(temporary) && temporary && File.exist?(temporary)
    end
  end
end
