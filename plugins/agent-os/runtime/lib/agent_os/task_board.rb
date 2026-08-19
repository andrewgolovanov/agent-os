# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "securerandom"
require "time"
require "uri"

module AgentOS
  class TaskBoard
    SCHEMA_VERSION = 1
    STATUSES = %w[inbox planned active waiting review done cancelled].freeze
    KINDS = %w[delivery review research maintenance coordination other].freeze
    SOURCE_KINDS = %w[slack_threads pull_requests figma deployments other].freeze
    SOURCE_TITLE_MAX_LENGTH = 96
    LABEL_KINDS = %w[slack_channel].freeze
    THREAD_ROLES = %w[coordination research implementation review follow_up other].freeze
    THREAD_STATUSES = %w[active idle done archived].freeze
    CURRENT_THREAD_STATUSES = %w[active idle].freeze
    THREAD_ORIGINS = %w[new fork routed automation].freeze
    ROUTING_STATES = %w[routing_pending routed cancelled].freeze
    FINISHED_STATUSES = %w[done cancelled].freeze
    FOLLOW_UP_STATUSES = %w[pending sent not_required].freeze

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    def initialize_store
      FileUtils.mkdir_p(items_dir)
      with_lock do
        all_tasks.each { |task| write_task!(task) }
        rebuild_board!
      end
    end

    def create(attributes)
      with_lock do
        now = timestamp
        task = {
          "schema_version" => SCHEMA_VERSION,
          "id" => attributes.fetch("id", generate_id),
          "title" => attributes.fetch("title"),
          "projects" => Array(attributes["projects"]),
          "labels" => [],
          "kind" => attributes.fetch("kind", "other"),
          "status" => attributes.fetch("status", "inbox"),
          "goal" => attributes.fetch("goal"),
          "summary" => attributes.fetch("summary", "Not started."),
          "constraints" => Array(attributes["constraints"]),
          "next_action" => attributes.fetch("next_action"),
          "waiting_on" => attributes["waiting_on"],
          "sources" => SOURCE_KINDS.to_h { |kind| [kind, []] },
          "codex_threads" => [],
          "activity" => empty_activity,
          "completion" => empty_completion,
          "routing" => [],
          "created_at" => now,
          "updated_at" => now
        }
        update_completion_for_status!(task, previous_status: "inbox", now: now)
        validate_task!(task)
        raise ArgumentError, "task already exists: #{task.fetch("id")}" if File.exist?(task_path(task.fetch("id")))

        FileUtils.mkdir_p(task_dir(task.fetch("id")))
        write_task!(task)
        append_event!(task.fetch("id"), "created", { "status" => task.fetch("status") }, now)
        rebuild_board!
        task
      end
    end

    def update(id, attributes)
      with_lock do
        task = read_task(id)
        previous_status = task.fetch("status")
        allowed = %w[title projects kind status goal summary constraints next_action waiting_on]
        attributes.each do |key, value|
          raise ArgumentError, "unsupported update field: #{key}" unless allowed.include?(key)

          task[key] = %w[projects constraints].include?(key) ? Array(value) : value
        end
        task["updated_at"] = timestamp
        update_completion_for_status!(task, previous_status: previous_status, now: task.fetch("updated_at"))
        validate_task!(task)
        write_task!(task)
        append_event!(id, "updated", attributes, task.fetch("updated_at"))
        rebuild_board!
        task
      end
    end

    def update_completion(id, follow_up_status:)
      raise ArgumentError, "invalid completion follow-up status: #{follow_up_status}" unless FOLLOW_UP_STATUSES.include?(follow_up_status)

      with_lock do
        task = read_task(id)
        raise ArgumentError, "completion follow-up is only available for done tasks" unless task.fetch("status") == "done"

        now = timestamp
        completion = task["completion"] ||= empty_completion
        completion["completed_at"] ||= task.fetch("updated_at")
        completion["follow_up_status"] = follow_up_status
        completion["follow_up_sent_at"] = follow_up_status == "sent" ? now : nil
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, "completion_follow_up_updated", completion, now)
        rebuild_board!
        task
      end
    end

    def attach_source(id, kind:, value:, title: nil)
      with_lock do
        task = read_task(id)
        raise ArgumentError, "invalid source kind: #{kind}" unless SOURCE_KINDS.include?(kind)

        source = canonical_source(kind, value, title: title)
        existing_task = all_tasks.find do |candidate|
          candidate.fetch("sources", {}).values.flatten.any? { |item| item["identity"] == source.fetch("identity") }
        end
        if kind == "pull_requests" && existing_task && existing_task.fetch("id") != id
          existing_id = existing_task.fetch("id")
          raise ArgumentError, "pull request already belongs to #{existing_id}: #{source.fetch("identity")}"
        end

        entries = task.fetch("sources").fetch(kind)
        existing_source = entries.find { |item| item["identity"] == source.fetch("identity") }
        if existing_source
          return task unless source.key?("title") && existing_source["title"] != source.fetch("title")

          existing_source["title"] = source.fetch("title")
          task["updated_at"] = timestamp
          validate_task!(task)
          write_task!(task)
          append_event!(
            id,
            "source_title_updated",
            source.slice("identity", "title").merge("kind" => kind),
            task.fetch("updated_at")
          )
          rebuild_board!
          return task
        end

        source["added_at"] = timestamp
        entries << source
        if kind == "slack_threads" && task.fetch("status") == "done"
          completion = task["completion"] ||= empty_completion
          completion["completed_at"] ||= source.fetch("added_at")
          completion["follow_up_status"] = "pending"
          completion["follow_up_sent_at"] = nil
        end
        task["updated_at"] = source.fetch("added_at")
        validate_task!(task)
        write_task!(task)
        append_event!(id, "source_attached", source.merge("kind" => kind), task.fetch("updated_at"))
        rebuild_board!
        task
      end
    end

    def upsert_label(id, key:, name:, kind:)
      normalized = {
        "key" => key.to_s.strip,
        "name" => name.to_s.strip,
        "kind" => kind
      }
      validate_label!(normalized)

      with_lock do
        task = read_task(id)
        labels = task["labels"] ||= []
        existing = labels.find { |label| label["key"] == normalized.fetch("key") }
        return task if existing == normalized

        existing ? existing.replace(normalized) : labels << normalized
        task["updated_at"] = timestamp
        validate_task!(task)
        write_task!(task)
        append_event!(id, "label_upserted", normalized, task.fetch("updated_at"))
        rebuild_board!
        task
      end
    end

    def attach_codex(id, thread_id:, role:, status: "active", origin: "new", project: nil, title: nil, parent_thread_id: nil)
      with_lock do
        task = read_task(id)
        raise ArgumentError, "invalid Codex role: #{role}" unless THREAD_ROLES.include?(role)
        raise ArgumentError, "invalid Codex status: #{status}" unless THREAD_STATUSES.include?(status)
        raise ArgumentError, "invalid Codex origin: #{origin}" unless THREAD_ORIGINS.include?(origin)
        raise ArgumentError, "thread_id is required" if thread_id.to_s.strip.empty?

        if CURRENT_THREAD_STATUSES.include?(status)
          existing_task = all_tasks.find do |candidate|
            candidate.fetch("codex_threads", []).any? do |item|
              item["thread_id"] == thread_id && CURRENT_THREAD_STATUSES.include?(item["status"])
            end
          end
          if existing_task && existing_task.fetch("id") != id
            raise ArgumentError, "Codex task already belongs to #{existing_task.fetch("id")}: #{thread_id}"
          end
        end

        membership = task.fetch("codex_threads").find { |item| item["thread_id"] == thread_id }
        now = timestamp
        values = {
          "thread_id" => thread_id,
          "url" => "codex://threads/#{thread_id}",
          "role" => role,
          "status" => status,
          "origin" => origin,
          "project" => project,
          "title" => title,
          "parent_thread_id" => parent_thread_id
        }.compact
        if membership
          membership.merge!(values)
          action = "codex_updated"
        else
          values["added_at"] = now
          task.fetch("codex_threads") << values
          action = "codex_attached"
        end
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, action, values, now)
        rebuild_board!
        task
      end
    end

    def reassign_codex(from_id, to_id, thread_id:, turn_id:, started_at:, role: "implementation", origin: "automation", project: nil)
      raise ArgumentError, "source and target tasks must differ" if from_id == to_id
      raise ArgumentError, "invalid Codex role: #{role}" unless THREAD_ROLES.include?(role)
      raise ArgumentError, "invalid Codex origin: #{origin}" unless THREAD_ORIGINS.include?(origin)
      raise ArgumentError, "thread_id is required" if thread_id.to_s.strip.empty?
      identity = activity_identity(thread_id, turn_id)

      with_lock do
        source = read_task(from_id)
        target = read_task(to_id)
        source_membership = source.fetch("codex_threads").find { |item| item["thread_id"] == thread_id }
        unless source_membership && CURRENT_THREAD_STATUSES.include?(source_membership["status"])
          raise ArgumentError, "Codex task is not currently attached to #{from_id}: #{thread_id}"
        end

        current_owners = all_tasks.select do |candidate|
          candidate.fetch("codex_threads", []).any? do |item|
            item["thread_id"] == thread_id && CURRENT_THREAD_STATUSES.include?(item["status"])
          end
        end
        unless current_owners.map { |task| task.fetch("id") } == [from_id]
          raise ArgumentError, "Codex task current ownership is ambiguous: #{thread_id}"
        end

        source_activity = source["activity"] ||= empty_activity
        source_turn = source_activity.fetch("turns").find { |candidate| candidate["identity"] == identity }
        raise ArgumentError, "cannot reassign a completed turn: #{turn_id}" if source_turn && source_turn["stopped_at"]

        other_open_turn = source_activity.fetch("turns").find do |candidate|
          candidate["session_id"] == thread_id && candidate["stopped_at"].nil? && candidate["identity"] != identity
        end
        raise ArgumentError, "cannot reassign while another turn is active: #{other_open_turn.fetch("turn_id")}" if other_open_turn

        target_activity = target["activity"] ||= empty_activity
        if target_activity.fetch("turns").any? { |candidate| candidate["identity"] == identity }
          raise ArgumentError, "target task already contains turn: #{turn_id}"
        end

        turn = source_turn || {
          "identity" => identity,
          "session_id" => thread_id,
          "turn_id" => turn_id,
          "started_at" => normalize_timestamp(started_at),
          "stopped_at" => nil,
          "duration_seconds" => nil
        }
        source_activity.fetch("turns").delete(source_turn) if source_turn
        target_activity.fetch("turns") << turn

        now = timestamp
        source_membership["status"] = "archived"
        source["updated_at"] = now

        target_membership = target.fetch("codex_threads").find { |item| item["thread_id"] == thread_id }
        membership_values = {
          "thread_id" => thread_id,
          "url" => "codex://threads/#{thread_id}",
          "role" => role,
          "status" => "active",
          "origin" => origin,
          "project" => project
        }.compact
        if target_membership
          target_membership.merge!(membership_values)
        else
          membership_values["added_at"] = now
          target.fetch("codex_threads") << membership_values
        end
        target["updated_at"] = now

        validate_task!(source)
        validate_task!(target)
        write_task!(source)
        write_task!(target)
        event = {
          "thread_id" => thread_id,
          "turn_id" => turn_id,
          "from_task_id" => from_id,
          "to_task_id" => to_id,
          "started_at" => turn.fetch("started_at")
        }
        append_event!(from_id, "codex_reassigned_out", event, now)
        append_event!(to_id, "codex_reassigned_in", event, now)
        rebuild_board!
        target
      end
    end

    def activity_start(id, session_id:, turn_id:, at: nil)
      with_lock do
        task = read_task(id)
        membership = ensure_codex_membership!(task, session_id)
        activity = task["activity"] ||= empty_activity
        identity = activity_identity(session_id, turn_id)
        return task if activity.fetch("turns").any? { |turn| turn["identity"] == identity }

        now = normalize_timestamp(at)
        turn = {
          "identity" => identity,
          "session_id" => session_id,
          "turn_id" => turn_id,
          "started_at" => now,
          "stopped_at" => nil,
          "duration_seconds" => nil
        }
        activity.fetch("turns") << turn
        membership["status"] = "active"
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, "activity_started", turn, now)
        rebuild_board!
        task
      end
    end

    def activity_stop(id, session_id:, turn_id:, at: nil)
      with_lock do
        task = read_task(id)
        membership = ensure_codex_membership!(task, session_id)
        activity = task["activity"] ||= empty_activity
        identity = activity_identity(session_id, turn_id)
        turn = activity.fetch("turns").find { |candidate| candidate["identity"] == identity }
        return task unless turn
        return task if turn["stopped_at"]

        now = normalize_timestamp(at)
        duration = [(Time.iso8601(now) - Time.iso8601(turn.fetch("started_at"))).round, 0].max
        turn["stopped_at"] = now
        turn["duration_seconds"] = duration
        activity["total_seconds"] = activity.fetch("total_seconds", 0) + duration
        membership["status"] = activity.fetch("turns").any? do |candidate|
          candidate["session_id"] == session_id && candidate["stopped_at"].nil?
        end ? "active" : "idle"
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, "activity_stopped", turn, now)
        rebuild_board!
        task
      end
    end

    def add_routing(id, project:, role:, reason_code:, reason:, repository_paths: [])
      with_lock do
        task = read_task(id)
        now = timestamp
        route = {
          "id" => "route_#{SecureRandom.hex(4)}",
          "project" => project,
          "repository_paths" => Array(repository_paths),
          "role" => role,
          "state" => "routing_pending",
          "attempts" => 0,
          "reason_code" => reason_code,
          "reason" => reason,
          "created_at" => now,
          "updated_at" => now
        }
        task.fetch("routing") << route
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, "routing_created", route, now)
        rebuild_board!
        task
      end
    end

    def update_routing(id, route_id:, state:, attempted: false, reason: nil, codex_thread_id: nil)
      raise ArgumentError, "invalid routing state: #{state}" unless ROUTING_STATES.include?(state)

      with_lock do
        task = read_task(id)
        route = task.fetch("routing").find { |candidate| candidate["id"] == route_id }
        raise ArgumentError, "unknown route: #{route_id}" unless route

        now = timestamp
        route["state"] = state
        route["attempts"] = route.fetch("attempts", 0) + 1 if attempted
        route["reason"] = reason if reason
        route["codex_thread_id"] = codex_thread_id if codex_thread_id
        route["updated_at"] = now
        task["updated_at"] = now
        validate_task!(task)
        write_task!(task)
        append_event!(id, "routing_updated", route, now)
        rebuild_board!
        task
      end
    end

    def tasks
      all_tasks.sort_by { |task| [task.fetch("updated_at"), task.fetch("id")] }.reverse
    end

    def summary(project: nil)
      selected = tasks
      selected = selected.select { |task| task.fetch("projects").include?(project) } if project
      summary_payload(selected, project: project)
    end

    def find_by_source(value)
      identity = canonical_identity(value)
      all_tasks.select do |task|
        task.fetch("sources", {}).values.flatten.any? { |source| source["identity"] == identity }
      end
    end

    def find_by_codex_thread(thread_id)
      all_tasks.select do |task|
        task.fetch("codex_threads", []).any? { |thread| thread["thread_id"] == thread_id }
      end
    end

    def read_task(id)
      path = task_path(id)
      raise ArgumentError, "unknown task: #{id}" unless File.file?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      raise ArgumentError, "invalid task JSON for #{id}: #{e.message}"
    end

    def validate!
      errors = []
      identities = Hash.new { |hash, key| hash[key] = [] }
      current_codex_threads = Hash.new { |hash, key| hash[key] = [] }
      tasks.each do |task|
        begin
          validate_task!(task)
        rescue ArgumentError => e
          errors << "#{task["id"] || "unknown"}: #{e.message}"
        end
        task.fetch("sources", {}).values.flatten.each do |source|
          identities[source["identity"]] << task.fetch("id")
        end
        task.fetch("codex_threads", []).each do |thread|
          if CURRENT_THREAD_STATUSES.include?(thread["status"])
            current_codex_threads[thread["thread_id"]] << task.fetch("id")
          end
        end
      end
      identities.each do |identity, task_ids|
        next unless identity.start_with?("github:") && task_ids.uniq.length > 1

        errors << "pull request source belongs to multiple tasks: #{identity}"
      end
      current_codex_threads.each do |thread_id, task_ids|
        next unless task_ids.uniq.length > 1

        errors << "Codex task has multiple current outcomes: #{thread_id}"
      end

      expected = board_payload(tasks)
      actual = File.file?(board_path) ? JSON.parse(File.read(board_path)) : nil
      errors << "board.json is missing or stale" unless actual == expected
      expected_markdown = render_board(tasks)
      actual_markdown = File.file?(board_markdown_path) ? File.read(board_markdown_path) : nil
      errors << "BOARD.md is missing or stale" unless actual_markdown == expected_markdown
      errors
    rescue JSON::ParserError => e
      ["invalid board.json: #{e.message}"]
    end

    def canonical_identity(value)
      string = value.to_s.strip
      return string if string.match?(/\A(?:slack|github|figma|deployment|codex|other):/)

      if (match = string.match(%r{https?://[^/]*slack\.com/archives/([A-Z0-9]+)/p(\d{10})(\d{1,6})}i))
        fraction = match[3].ljust(6, "0")
        return "slack:#{match[1].upcase}:#{match[2]}.#{fraction}"
      end
      if (match = string.match(%r{https?://github\.com/([^/]+)/([^/]+)/pull/(\d+)}i))
        return "github:#{match[1].downcase}/#{match[2].downcase}##{match[3]}"
      end
      if (match = string.match(%r{https?://(?:www\.)?figma\.com/(?:design|file)/([^/?]+)}i))
        return "figma:#{match[1]}"
      end
      if (match = string.match(%r{\Acodex://threads/([^/?#]+)}i))
        return "codex:#{match[1]}"
      end

      uri = URI.parse(string)
      if uri.is_a?(URI::HTTP)
        uri.fragment = nil
        uri.path = uri.path.sub(%r{/+\z}, "") unless uri.path == "/"
        return "other:#{uri}"
      end
      "other:#{string}"
    rescue URI::InvalidURIError
      "other:#{string}"
    end

    private

    def task_dir(id)
      File.join(items_dir, id)
    end

    def task_path(id)
      File.join(task_dir(id), "task.json")
    end

    def events_path(id)
      File.join(task_dir(id), "events.jsonl")
    end

    def status_path(id)
      File.join(task_dir(id), "STATUS.md")
    end

    def items_dir
      File.join(root, "items")
    end

    def board_path
      File.join(root, "board.json")
    end

    def board_markdown_path
      File.join(root, "BOARD.md")
    end

    def lock_path
      File.join(root, ".lock")
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

    def timestamp
      Time.now.utc.iso8601(6)
    end

    def normalize_timestamp(value)
      return timestamp if value.nil?
      return value.utc.iso8601(6) if value.is_a?(Time)

      string = value.to_s.strip
      time = string.match?(/\A\d+(?:\.\d+)?\z/) ? Time.at(string.to_f) : Time.iso8601(string)
      time.utc.iso8601(6)
    rescue ArgumentError
      raise ArgumentError, "invalid timestamp: #{value}"
    end

    def generate_id
      "task_#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}_#{SecureRandom.hex(3)}"
    end

    def empty_activity
      { "total_seconds" => 0, "turns" => [] }
    end

    def empty_completion
      {
        "completed_at" => nil,
        "follow_up_status" => "not_required",
        "follow_up_sent_at" => nil
      }
    end

    def update_completion_for_status!(task, previous_status:, now:)
      return unless task.fetch("status") != previous_status

      completion = task["completion"] ||= empty_completion
      if task.fetch("status") == "done"
        completion["completed_at"] = now
        completion["follow_up_status"] = task.dig("sources", "slack_threads")&.any? ? "pending" : "not_required"
        completion["follow_up_sent_at"] = nil
      else
        completion.replace(empty_completion)
      end
    end

    def activity_identity(session_id, turn_id)
      raise ArgumentError, "session_id is required" if session_id.to_s.strip.empty?
      raise ArgumentError, "turn_id is required" if turn_id.to_s.strip.empty?

      "codex:#{session_id}:#{turn_id}"
    end

    def format_duration(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, remaining_seconds = remainder.divmod(60)
      parts = []
      parts << "#{hours}h" if hours.positive?
      parts << "#{minutes}m" if minutes.positive?
      parts << "#{remaining_seconds}s" if remaining_seconds.positive? || parts.empty?
      parts.join(" ")
    end

    def ensure_codex_membership!(task, session_id)
      membership = task.fetch("codex_threads", []).find { |thread| thread["thread_id"] == session_id }
      return membership if membership

      raise ArgumentError, "Codex task is not attached to #{task.fetch("id")}: #{session_id}"
    end

    def all_tasks
      Dir.glob(File.join(items_dir, "*", "task.json")).sort.map do |path|
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        { "id" => File.basename(File.dirname(path)), "_parse_error" => e.message }
      end
    end

    def canonical_source(kind, value, title: nil)
      identity = canonical_identity(value)
      expected_prefix = {
        "slack_threads" => "slack:",
        "pull_requests" => "github:",
        "figma" => "figma:"
      }[kind]
      if expected_prefix && !identity.start_with?(expected_prefix)
        raise ArgumentError, "#{kind} source is not a recognized #{expected_prefix.delete_suffix(":")} identity"
      end

      source = { "identity" => identity, "url" => value.to_s.strip }
      if title
        raise ArgumentError, "source titles are supported only for Slack threads" unless kind == "slack_threads"

        source["title"] = normalize_source_title(title)
      end
      source
    end

    def normalize_source_title(value)
      title = CGI.unescapeHTML(value.to_s)
        .gsub(/<(?:https?:\/\/|mailto:)[^>|]+\|([^>]+)>/) { Regexp.last_match(1) }
        .gsub(/<(?:https?:\/\/|mailto:)[^>]+>/, "")
        .gsub(/<#[^>|]+\|([^>]+)>/) { "##{Regexp.last_match(1)}" }
        .gsub(/<[@!][^>]+>/, "")
        .gsub(/[`*_~]+/, "")
        .gsub(/\s+/, " ")
        .strip
      raise ArgumentError, "source title is empty after normalization" if title.empty?

      return title if title.length <= SOURCE_TITLE_MAX_LENGTH

      "#{title[0, SOURCE_TITLE_MAX_LENGTH - 1].rstrip}…"
    end

    def validate_task!(task)
      raise ArgumentError, "task must be a mapping" unless task.is_a?(Hash)
      raise ArgumentError, "schema_version must be #{SCHEMA_VERSION}" unless task["schema_version"] == SCHEMA_VERSION
      raise ArgumentError, "invalid id" unless task["id"].to_s.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)
      raise ArgumentError, "title is required" if task["title"].to_s.strip.empty?
      unless task["projects"].is_a?(Array) && task["projects"].all? { |value| !value.to_s.empty? }
        raise ArgumentError, "projects must be an array of non-empty keys"
      end
      labels = task.fetch("labels", [])
      raise ArgumentError, "labels must be an array" unless labels.is_a?(Array)
      labels.each do |label|
        validate_label!(label)
      end
      label_keys = labels.map { |label| label.fetch("key") }
      raise ArgumentError, "label keys must be unique" unless label_keys.uniq.length == label_keys.length
      raise ArgumentError, "invalid kind: #{task["kind"]}" unless KINDS.include?(task["kind"])
      raise ArgumentError, "invalid status: #{task["status"]}" unless STATUSES.include?(task["status"])
      %w[goal summary next_action created_at updated_at].each do |field|
        raise ArgumentError, "#{field} is required" if task[field].to_s.strip.empty?
      end
      unless task["constraints"].is_a?(Array) && task["constraints"].all? { |value| !value.to_s.strip.empty? }
        raise ArgumentError, "constraints must be an array of non-empty strings"
      end
      raise ArgumentError, "waiting tasks need waiting_on" if task["status"] == "waiting" && task["waiting_on"].to_s.strip.empty?

      sources = task["sources"]
      raise ArgumentError, "sources must be a mapping" unless sources.is_a?(Hash)
      raise ArgumentError, "sources keys are invalid" unless sources.keys.sort == SOURCE_KINDS.sort
      sources.each_value do |entries|
        raise ArgumentError, "source entries must be arrays" unless entries.is_a?(Array)
        entries.each do |source|
          raise ArgumentError, "source identity is required" if source["identity"].to_s.strip.empty?
          raise ArgumentError, "source URL/value is required" if source["url"].to_s.strip.empty?
          next unless source.key?("title")

          unless source["title"] == normalize_source_title(source["title"])
            raise ArgumentError, "source title must be normalized and at most #{SOURCE_TITLE_MAX_LENGTH} characters"
          end
        end
      end

      raise ArgumentError, "codex_threads must be an array" unless task["codex_threads"].is_a?(Array)
      task["codex_threads"].each do |thread|
        raise ArgumentError, "invalid Codex role" unless THREAD_ROLES.include?(thread["role"])
        raise ArgumentError, "invalid Codex status" unless THREAD_STATUSES.include?(thread["status"])
        raise ArgumentError, "invalid Codex origin" unless THREAD_ORIGINS.include?(thread["origin"])
      end

      if task.key?("activity")
        activity = task["activity"]
        raise ArgumentError, "activity must be a mapping" unless activity.is_a?(Hash)
        raise ArgumentError, "activity total_seconds must be a non-negative integer" unless activity["total_seconds"].is_a?(Integer) && activity["total_seconds"] >= 0
        raise ArgumentError, "activity turns must be an array" unless activity["turns"].is_a?(Array)

        identities = []
        activity.fetch("turns").each do |turn|
          identity = activity_identity(turn["session_id"], turn["turn_id"])
          raise ArgumentError, "activity identity mismatch" unless turn["identity"] == identity
          raise ArgumentError, "activity started_at is required" if turn["started_at"].to_s.strip.empty?
          Time.iso8601(turn.fetch("started_at"))
          if turn["stopped_at"]
            Time.iso8601(turn.fetch("stopped_at"))
            unless turn["duration_seconds"].is_a?(Integer) && turn["duration_seconds"] >= 0
              raise ArgumentError, "completed activity duration must be a non-negative integer"
            end
          elsif !turn["duration_seconds"].nil?
            raise ArgumentError, "active activity duration must be null"
          end
          identities << identity
        end
        raise ArgumentError, "activity turn identities must be unique" unless identities.uniq.length == identities.length
        completed_total = activity.fetch("turns").sum { |turn| turn["duration_seconds"] || 0 }
        raise ArgumentError, "activity total_seconds is stale" unless completed_total == activity.fetch("total_seconds")
      end

      if task.key?("completion")
        completion = task["completion"]
        raise ArgumentError, "completion must be a mapping" unless completion.is_a?(Hash)
        unless FOLLOW_UP_STATUSES.include?(completion["follow_up_status"])
          raise ArgumentError, "invalid completion follow-up status"
        end
        if task.fetch("status") == "done"
          raise ArgumentError, "done tasks need completion completed_at" if completion["completed_at"].to_s.strip.empty?
          Time.iso8601(completion.fetch("completed_at"))
        elsif completion["completed_at"] || completion["follow_up_status"] != "not_required" || completion["follow_up_sent_at"]
          raise ArgumentError, "unfinished and cancelled tasks cannot retain completion state"
        end
        if completion["follow_up_status"] == "sent"
          raise ArgumentError, "sent completion follow-up needs follow_up_sent_at" if completion["follow_up_sent_at"].to_s.strip.empty?
          Time.iso8601(completion.fetch("follow_up_sent_at"))
        elsif completion["follow_up_sent_at"]
          raise ArgumentError, "only sent completion follow-up may have follow_up_sent_at"
        end
      end

      raise ArgumentError, "routing must be an array" unless task["routing"].is_a?(Array)
      task["routing"].each do |route|
        raise ArgumentError, "invalid routing state" unless ROUTING_STATES.include?(route["state"])
      end
      true
    end

    def validate_label!(label)
      raise ArgumentError, "label must be a mapping" unless label.is_a?(Hash)
      raise ArgumentError, "label key is required" if label["key"].to_s.strip.empty?
      raise ArgumentError, "label name is required" if label["name"].to_s.strip.empty?
      raise ArgumentError, "invalid label kind: #{label["kind"]}" unless LABEL_KINDS.include?(label["kind"])

      if label["kind"] == "slack_channel"
        raise ArgumentError, "invalid Slack channel label key" unless label["key"].match?(/\Aslack:[A-Z0-9]+\z/)
        raise ArgumentError, "invalid Slack channel label name" unless label["name"].match?(/\A#[a-z0-9][a-z0-9_-]*\z/i)
      end
      true
    end

    def write_task!(task)
      atomic_write(task_path(task.fetch("id")), JSON.pretty_generate(task) + "\n")
      atomic_write(status_path(task.fetch("id")), render_status(task))
    end

    def append_event!(id, action, details, at)
      event = { "at" => at, "action" => action, "details" => details }
      File.open(events_path(id), "a", 0o600) do |file|
        file.write(JSON.generate(event) + "\n")
        file.flush
        file.fsync
      end
    end

    def rebuild_board!
      current_tasks = tasks
      atomic_write(board_path, JSON.pretty_generate(board_payload(current_tasks)) + "\n")
      atomic_write(board_markdown_path, render_board(current_tasks))
    end

    def board_payload(current_tasks)
      {
        "schema_version" => SCHEMA_VERSION,
        "summary" => summary_payload(current_tasks),
        "tasks" => current_tasks.map do |task|
          {
            "id" => task.fetch("id"),
            "title" => task.fetch("title"),
            "projects" => task.fetch("projects"),
            "labels" => task.fetch("labels", []),
            "kind" => task.fetch("kind"),
            "status" => task.fetch("status"),
            "next_action" => task.fetch("next_action"),
            "updated_at" => task.fetch("updated_at"),
            "source_identities" => task.fetch("sources").values.flatten.map { |source| source.fetch("identity") }.sort,
            "codex_thread_ids" => task.fetch("codex_threads").map { |thread| thread.fetch("thread_id") }.sort,
            "routing_pending" => task.fetch("routing").count { |route| route["state"] == "routing_pending" },
            "tracked_seconds" => task.dig("activity", "total_seconds") || 0,
            "active_turns" => task.fetch("activity", {}).fetch("turns", []).count { |turn| turn["stopped_at"].nil? },
            "completed_at" => task.dig("completion", "completed_at"),
            "completion_follow_up" => task.dig("completion", "follow_up_status")
          }
        end
      }
    end

    def summary_payload(current_tasks, project: nil)
      by_status = STATUSES.to_h { |status| [status, current_tasks.count { |task| task["status"] == status }] }
      unfinished = current_tasks.reject { |task| FINISHED_STATUSES.include?(task["status"]) }
      {
        "scope" => project ? { "project" => project } : { "all_projects" => true },
        "total" => current_tasks.length,
        "unfinished_total" => unfinished.length,
        "finished_total" => current_tasks.length - unfinished.length,
        "by_status" => by_status,
        "unfinished_by_status" => by_status.reject { |status, _| FINISHED_STATUSES.include?(status) },
        "tracked_seconds" => current_tasks.sum { |task| task.dig("activity", "total_seconds") || 0 },
        "active_turns" => current_tasks.sum do |task|
          task.fetch("activity", {}).fetch("turns", []).count { |turn| turn["stopped_at"].nil? }
        end
      }
    end

    def render_board(current_tasks)
      summary = summary_payload(current_tasks)
      status_labels = {
        "inbox" => "Входящие",
        "planned" => "Запланировано",
        "active" => "В работе",
        "waiting" => "Ожидание",
        "review" => "Проверка",
        "done" => "Завершено",
        "cancelled" => "Отменено"
      }
      status_counts = summary.fetch("by_status").each_with_object([]) do |(status, count), values|
        values << "`#{status}`: #{count}" if count.positive?
      end
      last_updated = current_tasks.map { |task| task.fetch("updated_at") }.max
      sections = STATUSES.each_with_object([]) do |status, values|
        matching = current_tasks.select { |task| task.fetch("status") == status }
        next if matching.empty?

        cards = matching.map do |task|
          projects = task.fetch("projects").empty? ? "не назначен" : task.fetch("projects").map { |project| "`#{project}`" }.join(", ")
          labels = task.fetch("labels", []).map { |label| "`#{label.fetch("name")}`" }.join(", ")
          activity = task.fetch("activity", empty_activity)
          active_turns = activity.fetch("turns").count { |turn| turn["stopped_at"].nil? }
          linked_threads = task.fetch("codex_threads")
          codex_state = if linked_threads.empty?
                          "не привязан"
                        else
                          states = linked_threads.group_by { |thread| thread.fetch("status") }
                          states.map { |thread_status, threads| "`#{thread_status}`: #{threads.length}" }.join(", ")
                        end
          blocker = task["waiting_on"].to_s.strip
          blocker_line = blocker.empty? ? nil : "- Блокировка: #{blocker}"

          [
            "### #{task.fetch("title")}",
            "",
            "`#{task.fetch("id")}` · проект: #{projects} · тип: `#{task.fetch("kind")}`",
            "",
            labels.empty? ? nil : "- Метки: #{labels}",
            "- Состояние: #{task.fetch("summary")}",
            "- Следующий шаг: #{task.fetch("next_action")}",
            blocker_line,
            "- Codex: #{codex_state}; active turns: #{active_turns}",
            "- Учтённое Codex-время: #{format_duration(activity.fetch("total_seconds"))}",
            "- Обновлено: `#{task.fetch("updated_at")}`",
            "- [Открыть полную карточку](items/#{task.fetch("id")}/STATUS.md)"
          ].compact.join("\n")
        end

        values << "## #{status_labels.fetch(status)} (`#{status}`) — #{matching.length}\n\n#{cards.join("\n\n")}"
      end

      <<~MARKDOWN
        # Agent OS Task Board

        Этот файл генерируется автоматически из canonical `work/items/*/task.json`. Не редактируйте его вручную: каждое изменение через `tools/task-board`, Slack intake или activity hook пересобирает dashboard.

        ## Сводка

        - Невыполнено: **#{summary.fetch("unfinished_total")}**
        - Всего карточек: #{summary.fetch("total")}
        - Статусы: #{status_counts.empty? ? "нет задач" : status_counts.join(", ")}
        - Учтённое Codex-время: #{format_duration(summary.fetch("tracked_seconds"))}
        - Активные Codex turns: #{summary.fetch("active_turns")}
        - Последнее изменение: #{last_updated ? "`#{last_updated}`" : "нет задач"}

        #{sections.empty? ? "Задач пока нет." : sections.join("\n\n")}
      MARKDOWN
    end

    def render_status(task)
      blockers = task["waiting_on"].to_s.strip.empty? ? "None." : task["waiting_on"]
      source_lines = task.fetch("sources").flat_map do |kind, entries|
        entries.map { |source| "- `#{kind}`: [#{source.fetch("identity")}](#{source.fetch("url")})" }
      end
      thread_lines = task.fetch("codex_threads").map do |thread|
        "- [#{thread.fetch("thread_id")}](#{thread.fetch("url")}) — #{thread.fetch("role")}, #{thread.fetch("status")}"
      end
      activity = task.fetch("activity", empty_activity)
      active_turns = activity.fetch("turns").count { |turn| turn["stopped_at"].nil? }
      constraint_lines = task.fetch("constraints").map { |constraint| "- #{constraint}" }
      labels = task.fetch("labels", []).map { |label| "`#{label.fetch("name")}`" }.join(", ")
      completion = task["completion"] || empty_completion
      completion_lines = if task.fetch("status") == "done"
                           [
                             "Completed at: `#{completion["completed_at"] || task.fetch("updated_at")}`",
                             "Follow-up: `#{completion.fetch("follow_up_status", "not_required")}`",
                             completion["follow_up_sent_at"] ? "Follow-up sent at: `#{completion["follow_up_sent_at"]}`" : nil
                           ].compact.join("\n\n")
                         else
                           "Not applicable."
                         end
      <<~MARKDOWN
        # #{task.fetch("title")}

        Task ID: `#{task.fetch("id")}`

        Status: `#{task.fetch("status")}`

        Projects: #{task.fetch("projects").empty? ? "Unassigned" : task.fetch("projects").map { |project| "`#{project}`" }.join(", ")}

        Labels: #{labels.empty? ? "None." : labels}

        ## Goal

        #{task.fetch("goal")}

        ## Current state

        #{task.fetch("summary")}

        ## Decisions and constraints

        #{constraint_lines.empty? ? "None." : constraint_lines.join("\n")}

        ## Next action

        #{task.fetch("next_action")}

        ## Blockers

        #{blockers}

        ## Sources

        #{source_lines.empty? ? "None." : source_lines.join("\n")}

        ## Codex tasks

        #{thread_lines.empty? ? "None." : thread_lines.join("\n")}

        ## Tracked Codex activity

        Completed turn time: #{format_duration(activity.fetch("total_seconds"))} (#{activity.fetch("total_seconds")} seconds).

        Active turns: #{active_turns}.

        ## Completion

        #{completion_lines}
      MARKDOWN
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
