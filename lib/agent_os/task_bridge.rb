# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "time"
require "uri"
require "yaml"
require_relative "task_board"

module AgentOS
  class TaskBridge
    SCHEMA_VERSION = 1
    CLAIMABLE_STATUSES = %w[inbox planned active waiting review].freeze
    AUTO_ACTIVATE_STATUSES = %w[inbox planned review].freeze
    CHECKPOINT_STATUSES = %w[active waiting review].freeze
    MUTATING_TOOLS = %w[apply_patch Edit Write].freeze

    attr_reader :agent_os_home, :source_root, :board, :runtime_root

    def initialize(agent_os_home:, source_root: agent_os_home, board_root: nil, registry_path: nil, config_path: nil, runtime_root: nil)
      @agent_os_home = File.expand_path(agent_os_home)
      @source_root = File.expand_path(source_root)
      @board = TaskBoard.new(board_root || File.join(@agent_os_home, "work"))
      @registry_path = registry_path || File.join(@agent_os_home, "config", "projects.yaml")
      @config_path = config_path || File.join(@agent_os_home, "config", "task-bridge.yaml")
      @runtime_root = File.expand_path(runtime_root || File.join(@agent_os_home, ".runtime", "task-bridge"))
    end

    def handle_prompt(payload, at: nil)
      session_id, turn_id = event_identity(payload)
      prompt = payload.fetch("prompt", "").to_s
      cwd = payload.fetch("cwd", "").to_s
      now = normalize_timestamp(at)
      project_key = cwd.strip.empty? ? nil : project_for_cwd(cwd)
      existing = board.find_by_codex_thread(session_id)
      raise ArgumentError, "Codex task belongs to multiple Task Board items: #{session_id}" if existing.length > 1

      return nil unless existing.one? || (project_key && enabled_for?(project_key))

      close_superseded_turns(session_id: session_id, current_turn_id: turn_id, now: now)

      state = record_prompt(
        session_id: session_id,
        turn_id: turn_id,
        project_key: project_key,
        prompt: prompt,
        started_at: now
      )

      if existing.one?
        task = existing.first
        membership = task.fetch("codex_threads").find { |item| item["thread_id"] == session_id }
        if membership && %w[done archived].include?(membership["status"])
          update_turn_state(
            session_id,
            turn_id,
            {
              "task_id" => task.fetch("id"),
              "claim_reason" => "archived_membership"
            }
          )
          return hook_context(archived_context(task, session_id))
        end
        ensure_task_active(task)
        board.activity_start(task.fetch("id"), session_id: session_id, turn_id: turn_id, at: state.fetch("started_at"))
        update_turn_state(
          session_id,
          turn_id,
          { "task_id" => task.fetch("id"), "claim_reason" => "existing_membership" }
        )
        return hook_context(bound_context(board.read_task(task.fetch("id")), session_id, turn_id))
      end

      return nil unless project_key && enabled_for?(project_key)

      candidates = candidates_for(project_key, prompt)
      update_turn_state(
        session_id,
        turn_id,
        {
          "candidates" => candidates.map do |candidate|
            {
              "task_id" => candidate.fetch("task_id"),
              "exact" => candidate.fetch("exact"),
              "reasons" => candidate.fetch("reasons"),
              "score" => candidate.fetch("score")
            }
          end
        }
      )
      exact = candidates.select { |candidate| candidate.fetch("exact") }
      if exact.one? && policy_for(project_key).fetch("auto_claim", "exact_sources") == "exact_sources"
        task = claim(
          exact.first.fetch("task_id"),
          session_id: session_id,
          turn_id: turn_id,
          project_key: project_key,
          reason: exact.first.fetch("reasons").join(", ")
        )
        return hook_context(bound_context(task, session_id, turn_id))
      end

      hook_context(unbound_context(project_key, session_id, turn_id, candidates, exact.length > 1))
    end

    def handle_stop(payload, at: nil)
      session_id, turn_id = event_identity(payload)
      now = normalize_timestamp(at)
      existing = board.find_by_codex_thread(session_id)
      raise ArgumentError, "Codex task belongs to multiple Task Board items: #{session_id}" if existing.length > 1

      board.activity_stop(existing.first.fetch("id"), session_id: session_id, turn_id: turn_id, at: now) if existing.one?
      state = update_turn_state(session_id, turn_id, { "stopped_at" => now }, create: false)
      return { "continue" => true } unless state && state["material_change"] && state["checkpointed_at"].nil?

      task = existing.one? ? existing.first : nil
      project_key = state["project"] || (task && task.fetch("projects").first)
      return { "continue" => true } unless checkpoint_required_for?(project_key)

      reason = checkpoint_reminder(state, task)
      { "decision" => "block", "reason" => reason }
    end

    def mark_material(payload, at: nil)
      session_id, turn_id = event_identity(payload)
      tool_name = payload.fetch("tool_name", "").to_s
      return { "continue" => true } unless MUTATING_TOOLS.include?(tool_name)

      update_turn_state(
        session_id,
        turn_id,
        { "material_change" => true, "material_change_at" => normalize_timestamp(at), "material_tool" => tool_name },
        create: false
      )
      { "continue" => true }
    end

    def claim(task_id, session_id:, turn_id:, project_key: nil, role: "implementation", reason: "agent_selected")
      validate_identity!(session_id, "session_id")
      validate_identity!(turn_id, "turn_id")
      state = read_turn_state(session_id, turn_id)
      project_key ||= state && state["project"]
      task = board.read_task(task_id)
      raise ArgumentError, "cannot claim finished task: #{task_id}" unless CLAIMABLE_STATUSES.include?(task.fetch("status"))

      if project_key
        if task.fetch("projects").empty?
          board.update(task_id, "projects" => [project_key])
          task = board.read_task(task_id)
        elsif !task.fetch("projects").include?(project_key)
          raise ArgumentError, "task #{task_id} does not belong to project #{project_key}"
        end
      end

      existing = board.find_by_codex_thread(session_id)
      if existing.any? && existing.first.fetch("id") != task_id
        raise ArgumentError, "Codex task already belongs to #{existing.first.fetch("id")}: #{session_id}"
      end

      board.attach_codex(
        task_id,
        thread_id: session_id,
        role: role,
        status: "active",
        origin: "automation",
        project: project_key
      )
      ensure_task_active(board.read_task(task_id))
      route_pending(task_id, session_id, project_key)

      started_at = state && state["started_at"]
      board.activity_start(task_id, session_id: session_id, turn_id: turn_id, at: started_at)
      if state && state["stopped_at"]
        board.activity_stop(task_id, session_id: session_id, turn_id: turn_id, at: state.fetch("stopped_at"))
      end
      update_turn_state(
        session_id,
        turn_id,
        { "task_id" => task_id, "claim_reason" => reason, "claimed_at" => timestamp },
        create: true,
        defaults: { "project" => project_key, "started_at" => started_at || timestamp }
      )
      board.read_task(task_id)
    end

    def checkpoint(task_id, session_id:, turn_id:, summary:, next_action:, status: nil, waiting_on: nil)
      validate_identity!(session_id, "session_id")
      validate_identity!(turn_id, "turn_id")
      raise ArgumentError, "summary is required" if summary.to_s.strip.empty?
      raise ArgumentError, "next_action is required" if next_action.to_s.strip.empty?

      linked = board.find_by_codex_thread(session_id)
      raise ArgumentError, "Codex task is not attached: #{session_id}" if linked.empty?
      raise ArgumentError, "Codex task belongs to #{linked.first.fetch("id")}, not #{task_id}" if linked.first.fetch("id") != task_id
      if status && !CHECKPOINT_STATUSES.include?(status)
        raise ArgumentError, "checkpoint status must be one of: #{CHECKPOINT_STATUSES.join(", ")}"
      end
      raise ArgumentError, "waiting checkpoint requires waiting_on" if status == "waiting" && waiting_on.to_s.strip.empty?

      attributes = { "summary" => summary, "next_action" => next_action }
      attributes["status"] = status if status
      if status == "waiting"
        attributes["waiting_on"] = waiting_on
      elsif %w[active review].include?(status)
        attributes["waiting_on"] = nil
      end
      task = board.update(task_id, attributes)
      update_turn_state(
        session_id,
        turn_id,
        { "task_id" => task_id, "checkpointed_at" => timestamp, "checkpoint_status" => task.fetch("status") },
        create: true
      )
      task
    end

    def context(session_id:, turn_id: nil)
      linked = board.find_by_codex_thread(session_id)
      if linked.one?
        membership = linked.first.fetch("codex_threads").find { |item| item["thread_id"] == session_id }
        return archived_context(linked.first, session_id) if membership && %w[done archived].include?(membership["status"])

        return bound_context(linked.first, session_id, turn_id)
      end

      state = turn_id ? read_turn_state(session_id, turn_id) : latest_turn_state(session_id)
      return "No Task Bridge context for #{session_id}." unless state

      candidates = Array(state["candidates"]).each_with_object([]) do |candidate, values|
        begin
          task = board.read_task(candidate.fetch("task_id"))
          values << candidate.merge("task" => task, "exact" => candidate["exact"] == true)
        rescue ArgumentError
          next
        end
      end
      unbound_context(state["project"], session_id, state["turn_id"], candidates, false)
    end

    def project_for_cwd(cwd)
      return nil if cwd.to_s.strip.empty?

      path = canonical_path(cwd)
      matches = projects.each_with_object([]) do |(key, project), values|
        next unless enabled_for?(key)

        project_roots(project).each do |root|
          canonical_root = canonical_path(root)
          values << [key, canonical_root.length] if path == canonical_root || path.start_with?(canonical_root + File::SEPARATOR)
        end
      end
      matches.max_by { |_, length| length }&.first
    end

    def reconcile_stale(now: nil, session_id: nil)
      validate_identity!(session_id, "session_id") if session_id
      current_time = Time.iso8601(normalize_timestamp(now))
      closed = []
      board.tasks.each do |task|
        project_key = task.fetch("projects").first
        next unless project_key && enabled_for?(project_key)

        timeout_seconds = policy_for(project_key).fetch("idle_timeout_minutes", 30).to_i * 60
        next unless timeout_seconds.positive?

        task.fetch("activity", {}).fetch("turns", []).each do |turn|
          next if turn["stopped_at"]
          next if session_id && turn["session_id"] != session_id

          started_at = Time.iso8601(turn.fetch("started_at"))
          deadline = started_at + timeout_seconds
          next if current_time < deadline

          board.activity_stop(
            task.fetch("id"),
            session_id: turn.fetch("session_id"),
            turn_id: turn.fetch("turn_id"),
            at: deadline
          )
          closed << turn.fetch("identity")
        end
      end
      closed
    end

    def enabled_for?(project_key)
      return false unless projects.key?(project_key)

      policy_for(project_key).fetch("enabled", true) == true
    end

    private

    def event_identity(payload)
      session_id = payload.fetch("session_id", "").to_s
      turn_id = payload.fetch("turn_id", "").to_s
      validate_identity!(session_id, "session_id")
      validate_identity!(turn_id, "turn_id")
      [session_id, turn_id]
    end

    def validate_identity!(value, name)
      raise ArgumentError, "#{name} is required" if value.to_s.empty?
      raise ArgumentError, "invalid #{name}" unless value.to_s.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)
    end

    def registry
      @registry ||= load_yaml(@registry_path)
    end

    def bridge_config
      @bridge_config ||= File.file?(@config_path) ? load_yaml(@config_path) : { "defaults" => {}, "projects" => {} }
    end

    def projects
      registry.fetch("projects", {})
    end

    def policy_for(project_key)
      bridge_config.fetch("defaults", {}).merge(bridge_config.fetch("projects", {}).fetch(project_key, {}))
    end

    def checkpoint_required_for?(project_key)
      policy_for(project_key).fetch("require_checkpoint", true) == true
    end

    def load_yaml(path)
      data = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
      raise ArgumentError, "#{path} must contain a mapping" unless data.is_a?(Hash)

      data
    rescue Psych::SyntaxError => e
      raise ArgumentError, "invalid YAML #{path}: #{e.message.lines.first.strip}"
    end

    def project_roots(project)
      repository_paths = Array(project["repositories"]).each_with_object([]) do |repository, values|
        values << repository["path"] if repository.is_a?(Hash) && repository["path"]
      end
      [project["wrapper"], *repository_paths].compact.uniq
    end

    def canonical_path(path)
      expanded = File.expand_path(path)
      File.exist?(expanded) ? File.realpath(expanded) : expanded
    end

    def candidates_for(project_key, prompt)
      tasks = board.tasks.select do |task|
        task.fetch("projects").include?(project_key) && CLAIMABLE_STATUSES.include?(task.fetch("status"))
      end
      prompt_signatures = source_signatures(prompt)
      explicit_ids = tasks.select { |task| prompt.include?(task.fetch("id")) }.map { |task| task.fetch("id") }
      tokens = lexical_tokens(prompt)

      tasks.map do |task|
        task_signatures = task.fetch("sources").values.flatten.flat_map { |source| source_signatures(source.fetch("url")) }.uniq
        shared = prompt_signatures & task_signatures
        reasons = []
        reasons << "explicit_task_id" if explicit_ids.include?(task.fetch("id"))
        reasons.concat(shared.map { |signature| "source:#{signature}" })
        searchable = [task.fetch("title"), task.fetch("goal"), task.fetch("summary"), task.fetch("next_action")].join(" ")
        score = (tokens & lexical_tokens(searchable)).length
        {
          "task_id" => task.fetch("id"),
          "task" => task,
          "exact" => reasons.any?,
          "reasons" => reasons,
          "score" => score
        }
      end.sort_by do |candidate|
        task = candidate.fetch("task")
        [candidate.fetch("exact") ? 0 : 1, -candidate.fetch("score"), status_priority(task.fetch("status")), task.fetch("id")]
      end.first(policy_for(project_key).fetch("max_candidates", 5))
    end

    def source_signatures(text)
      urls = URI.extract(text.to_s, %w[http https]).map { |url| url.sub(/[\]\[)}>.,;]+\z/, "") }
      urls.flat_map do |url|
        signatures = []
        identity = board.canonical_identity(url)
        signatures << identity if identity.start_with?("slack:", "github:")
        if (match = url.match(%r{figma\.com/(?:design|file)/([^/?#]+)}i))
          node = figma_node(url)
          signatures << "figma-node:#{match[1].downcase}:#{node}" if node
        end
        signatures
      rescue URI::InvalidURIError, ArgumentError
        []
      end.uniq
    end

    def figma_node(url)
      uri = URI.parse(url)
      pair = URI.decode_www_form(uri.query.to_s).find { |key, _value| %w[node-id node_id].include?(key) }
      raw = pair&.last
      raw&.tr("-", ":")
    end

    def lexical_tokens(text)
      text.to_s.downcase.scan(/[\p{L}\p{N}]+/).select { |token| token.length >= 4 }.uniq
    end

    def status_priority(status)
      %w[active review waiting planned inbox].index(status) || 99
    end

    def ensure_task_active(task)
      return task unless AUTO_ACTIVATE_STATUSES.include?(task.fetch("status"))

      board.update(task.fetch("id"), "status" => "active", "waiting_on" => nil)
    end

    def close_superseded_turns(session_id:, current_turn_id:, now:)
      current_time = Time.iso8601(normalize_timestamp(now))
      board.find_by_codex_thread(session_id).each do |task|
        project_key = task.fetch("projects").first
        timeout_seconds = policy_for(project_key).fetch("idle_timeout_minutes", 30).to_i * 60
        task.fetch("activity", {}).fetch("turns", []).each do |turn|
          next if turn["stopped_at"] || turn["turn_id"] == current_turn_id || turn["session_id"] != session_id

          started_at = Time.iso8601(turn.fetch("started_at"))
          board.activity_stop(
            task.fetch("id"),
            session_id: session_id,
            turn_id: turn.fetch("turn_id"),
            at: [current_time, started_at + timeout_seconds].min
          )
        end
      end
    end

    def route_pending(task_id, session_id, project_key)
      task = board.read_task(task_id)
      task.fetch("routing").select do |route|
        route["state"] == "routing_pending" && (!project_key || route["project"] == project_key)
      end.each do |route|
        board.update_routing(
          task_id,
          route_id: route.fetch("id"),
          state: "routed",
          attempted: true,
          reason: "Task Bridge attached exact Codex session.",
          codex_thread_id: session_id
        )
      end
    end

    def hook_context(context)
      {
        "hookSpecificOutput" => {
          "hookEventName" => "UserPromptSubmit",
          "additionalContext" => context
        }
      }
    end

    def bound_context(task, session_id, turn_id)
      constraints = task.fetch("constraints").empty? ? "None." : task.fetch("constraints").map { |item| "- #{item}" }.join("\n")
      waiting = task["waiting_on"].to_s.strip
      <<~TEXT.strip
        Agent OS Task Bridge: this Codex task is linked to one canonical outcome.
        Task ID: #{task.fetch("id")}
        Project: #{task.fetch("projects").join(", ")}
        Status: #{task.fetch("status")}
        Goal: #{task.fetch("goal")}
        Current state: #{task.fetch("summary")}
        Next action: #{task.fetch("next_action")}
        Waiting on: #{waiting.empty? ? "None." : waiting}
        Constraints:
        #{constraints}

        Before the final answer after any material file change, checkpoint the outcome with:
        #{File.join(source_root, "tools", "task-bridge")} checkpoint #{task.fetch("id")} --session-id #{session_id} --turn-id #{turn_id || "TURN_ID"} --summary "CURRENT VERIFIED STATE" --next-action "ONE CONCRETE NEXT STEP" --status active|review|waiting
        Use review only when implementation and relevant verification are ready. Never set done or cancelled automatically; those require explicit user acceptance. Do not create a duplicate Task Board item.
      TEXT
    end

    def unbound_context(project_key, session_id, turn_id, candidates, ambiguous)
      candidate_lines = candidates.map do |candidate|
        task = candidate.fetch("task")
        reasons = Array(candidate["reasons"])
        evidence = reasons.empty? ? "semantic suggestion only" : reasons.join(", ")
        "- #{task.fetch("id")} — #{task.fetch("title")} [#{task.fetch("status")}]; #{task.fetch("next_action")} (#{evidence})"
      end
      header = ambiguous ? "Multiple exact source matches were found; do not guess." : "No single exact task match was found."
      <<~TEXT.strip
        Agent OS Task Bridge: registered project #{project_key}, but this Codex task is not linked to a canonical outcome.
        #{header}
        Candidates:
        #{candidate_lines.empty? ? "- None." : candidate_lines.join("\n")}

        Before substantive mutations, inspect the candidates and claim exactly one with:
        #{File.join(source_root, "tools", "task-bridge")} claim TASK_ID --session-id #{session_id} --turn-id #{turn_id}
        If none represents the requested durable outcome, create one through tools/task-board and then claim it. Do not infer identity from title similarity alone. After material work, run the checkpoint command provided by the bound task context.
      TEXT
    end

    def archived_context(task, session_id)
      <<~TEXT.strip
        Agent OS Task Bridge: this legacy Codex task is archived because it contains work for multiple outcomes.
        Historical Task ID: #{task.fetch("id")}
        Session ID: #{session_id}

        Do not perform new project mutations in this mixed-history chat. Start a fresh chat in the registered project and include the exact Task Board ID or stable Slack/GitHub/Figma source in the first meaningful prompt. The archived membership remains read-only historical evidence and must not be reused for another outcome.
      TEXT
    end

    def checkpoint_reminder(state, task)
      task_id = task && task.fetch("id") || state["task_id"] || "TASK_ID"
      <<~TEXT.strip
        Task Bridge detected material file changes without a Task Board checkpoint. Before finishing, claim the correct outcome if needed, then run:
        #{File.join(source_root, "tools", "task-bridge")} checkpoint #{task_id} --session-id #{state.fetch("session_id")} --turn-id #{state.fetch("turn_id")} --summary "CURRENT VERIFIED STATE" --next-action "ONE CONCRETE NEXT STEP" --status active|review|waiting
        Use review only after implementation and relevant verification. Never mark done automatically.
      TEXT
    end

    def record_prompt(session_id:, turn_id:, project_key:, prompt:, started_at:)
      defaults = {
        "schema_version" => SCHEMA_VERSION,
        "session_id" => session_id,
        "turn_id" => turn_id,
        "project" => project_key,
        "started_at" => started_at,
        "prompt_sha256" => Digest::SHA256.hexdigest(prompt),
        "candidates" => [],
        "material_change" => false,
        "checkpointed_at" => nil,
        "stopped_at" => nil
      }
      update_turn_state(session_id, turn_id, {}, create: true, defaults: defaults)
    end

    def turn_state_path(session_id, turn_id)
      validate_identity!(session_id, "session_id")
      validate_identity!(turn_id, "turn_id")
      File.join(runtime_root, "sessions", session_id, "turns", "#{turn_id}.json")
    end

    def read_turn_state(session_id, turn_id)
      path = turn_state_path(session_id, turn_id)
      return nil unless File.file?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      raise ArgumentError, "invalid Task Bridge runtime state: #{e.message}"
    end

    def latest_turn_state(session_id)
      validate_identity!(session_id, "session_id")
      paths = Dir.glob(File.join(runtime_root, "sessions", session_id, "turns", "*.json"))
      path = paths.max_by { |candidate| File.mtime(candidate) }
      path ? JSON.parse(File.read(path)) : nil
    end

    def update_turn_state(session_id, turn_id, attributes, create: true, defaults: {})
      path = turn_state_path(session_id, turn_id)
      with_runtime_lock do
        state = File.file?(path) ? JSON.parse(File.read(path)) : nil
        return nil unless state || create

        state ||= {
          "schema_version" => SCHEMA_VERSION,
          "session_id" => session_id,
          "turn_id" => turn_id,
          "candidates" => [],
          "material_change" => false,
          "checkpointed_at" => nil,
          "stopped_at" => nil
        }.merge(defaults.compact)
        defaults.compact.each { |key, value| state[key] = value unless state.key?(key) }
        attributes.compact.each { |key, value| state[key] = value }
        atomic_write(path, JSON.pretty_generate(state) + "\n")
        state
      end
    end

    def with_runtime_lock
      FileUtils.mkdir_p(runtime_root)
      File.open(File.join(runtime_root, ".lock"), File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock.flock(File::LOCK_UN) rescue nil
      end
    end

    def atomic_write(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      temporary = "#{path}.tmp-#{Process.pid}-#{rand(1_000_000)}"
      File.open(temporary, "w", 0o600) do |file|
        file.write(content)
        file.flush
        file.fsync
      end
      File.rename(temporary, path)
    ensure
      File.delete(temporary) if defined?(temporary) && temporary && File.exist?(temporary)
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
  end
end
