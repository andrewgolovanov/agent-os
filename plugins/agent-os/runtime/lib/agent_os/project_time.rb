# frozen_string_literal: true

require "fileutils"
require "json"
require "time"
require "yaml"

module AgentOS
  class ProjectTime
    SCHEMA_VERSION = 1
    TERMINAL_EVENTS = %w[task_complete turn_aborted].freeze

    attr_reader :agent_os_home, :registry_path, :report_root

    def initialize(agent_os_home:, registry_path: nil, report_root: nil)
      @agent_os_home = File.expand_path(agent_os_home)
      @registry_path = File.expand_path(registry_path || File.join(@agent_os_home, "config", "projects.yaml"))
      @report_root = File.expand_path(report_root || File.join(@agent_os_home, "work", "reports", "project-time"))
    end

    def refresh(project_key:, session_roots: nil, at: nil)
      with_lock do
        project = project_config(project_key)
        existing = read_report(project_key, required: false)
        threads = scan_sessions(project_key, project, session_roots || default_session_roots)
        merge_hook_only_turns!(threads, existing, project)
        report = build_report(project_key, project, threads, refreshed_at: normalize_timestamp(at))
        write_report!(report)
        report
      end
    end

    def start(payload, at: nil)
      project_key = resolve_project(payload["cwd"])
      return nil unless project_key

      session_id = required_payload(payload, "session_id")
      turn_id = required_payload(payload, "turn_id")
      project = project_config(project_key)
      return nil if excluded_thread_ids(project).include?(session_id)

      with_lock do
        existing = read_report(project_key, required: false)
        threads = threads_by_id(existing)
        thread = threads[session_id] ||= empty_thread(session_id, payload["cwd"])
        turn = thread.fetch("turns").find { |item| item["turn_id"] == turn_id }
        unless turn
          started_at = normalize_timestamp(at)
          thread.fetch("turns") << {
            "identity" => turn_identity(session_id, turn_id),
            "turn_id" => turn_id,
            "started_at" => started_at,
            "stopped_at" => nil,
            "duration_seconds" => nil,
            "terminal_event" => nil,
            "source" => "hook"
          }
          thread["created_at"] ||= started_at
        end
        report = build_report(project_key, project, threads, refreshed_at: normalize_timestamp(at))
        write_report!(report)
        report
      end
    end

    def stop(payload, at: nil)
      project_key = resolve_project(payload["cwd"])
      return nil unless project_key

      session_id = required_payload(payload, "session_id")
      turn_id = required_payload(payload, "turn_id")
      project = project_config(project_key)
      return nil if excluded_thread_ids(project).include?(session_id)

      with_lock do
        existing = read_report(project_key, required: false)
        threads = threads_by_id(existing)
        thread = threads[session_id]
        return existing unless thread

        turn = thread.fetch("turns").find { |item| item["turn_id"] == turn_id }
        return existing unless turn
        return existing if turn["stopped_at"]

        stopped_at = normalize_timestamp(at)
        turn["stopped_at"] = stopped_at
        turn["duration_seconds"] = [(Time.iso8601(stopped_at) - Time.iso8601(turn.fetch("started_at"))).round, 0].max
        turn["terminal_event"] = "hook_stop"
        report = build_report(project_key, project, threads, refreshed_at: stopped_at)
        write_report!(report)
        report
      end
    end

    def report(project_key)
      read_report(project_key, required: true)
    end

    def validate(project_key: nil)
      paths = if project_key
                [json_path(project_key)]
              else
                Dir.glob(File.join(report_root, "*.json")).sort
              end
      paths.flat_map do |path|
        begin
          payload = JSON.parse(File.read(path))
          errors = validate_report(payload)
          markdown = File.file?(markdown_path(payload.fetch("project"))) ? File.read(markdown_path(payload.fetch("project"))) : nil
          errors << "generated Markdown is missing or stale" unless markdown == render_markdown(payload)
          errors.map { |error| "#{File.basename(path)}: #{error}" }
        rescue JSON::ParserError => e
          ["#{File.basename(path)}: invalid JSON: #{e.message}"]
        rescue KeyError => e
          ["#{File.basename(path)}: missing field: #{e.message}"]
        end
      end
    end

    private

    def registry
      @registry ||= YAML.safe_load(File.read(registry_path), permitted_classes: [], permitted_symbols: [], aliases: false)
    rescue Psych::SyntaxError => e
      raise ArgumentError, "invalid project registry: #{e.message.lines.first.strip}"
    end

    def project_config(project_key)
      project = registry.fetch("projects", {})[project_key]
      raise ArgumentError, "unknown project: #{project_key}" unless project.is_a?(Hash)

      project
    end

    def agent_os_timezone
      settings = registry["agent_os"] || registry["workspace"] || {}
      settings.fetch("timezone", "UTC").to_s.strip.then { |value| value.empty? ? "UTC" : value }
    end

    def resolve_project(cwd)
      path = File.expand_path(cwd.to_s)
      matches = registry.fetch("projects", {}).map do |key, project|
        roots = current_project_paths(project)
        longest = roots.select { |root| inside_path?(path, root) }.map(&:length).max
        [key, longest] if longest
      end.compact
      matches.max_by { |_, length| length }&.first
    end

    def current_project_paths(project)
      repository_paths = Array(project["repositories"]).map { |repository| repository["path"] }.compact
      ([project.fetch("root")] + repository_paths).compact.map do |path|
        File.expand_path(path)
      end.uniq
    end

    def historical_project_paths(project)
      Array(project.dig("activity", "historical_paths")).map { |path| File.expand_path(path) }
    end

    def all_project_paths(project)
      (current_project_paths(project) + historical_project_paths(project)).uniq
    end

    def included_thread_ids(project)
      Array(project.dig("activity", "include_thread_ids")).map(&:to_s)
    end

    def excluded_threads(project)
      Array(project.dig("activity", "exclude_threads")).map do |entry|
        entry.is_a?(Hash) ? entry.transform_keys(&:to_s) : { "id" => entry.to_s, "reason" => "Explicitly excluded." }
      end
    end

    def excluded_thread_ids(project)
      excluded_threads(project).map { |entry| entry["id"] }.compact
    end

    def inside_path?(candidate, root)
      expanded_root = File.expand_path(root)
      candidate == expanded_root || candidate.start_with?(expanded_root + File::SEPARATOR)
    end

    def default_session_roots
      codex_root = File.join(Dir.home, ".codex")
      [File.join(codex_root, "sessions"), File.join(codex_root, "archived_sessions")]
    end

    def scan_sessions(project_key, project, session_roots)
      allowed_paths = all_project_paths(project)
      included_ids = included_thread_ids(project)
      excluded_ids = excluded_thread_ids(project)
      threads = {}

      Array(session_roots).flat_map { |root| Dir.glob(File.join(File.expand_path(root), "**", "*.jsonl")) }.sort.each do |path|
        metadata = first_session_metadata(path)
        next unless metadata

        session_id = (metadata["id"] || metadata["session_id"]).to_s
        cwd = metadata["cwd"].to_s
        next if session_id.empty? || excluded_ids.include?(session_id)
        next unless included_ids.include?(session_id) || allowed_paths.any? { |root| inside_path?(File.expand_path(cwd), root) }

        imported = parse_session(path, session_id, cwd)
        merge_thread!(threads, imported)
      end
      threads
    end

    def first_session_metadata(path)
      File.foreach(path) do |line|
        row = JSON.parse(line)
        return row["payload"] || {} if row["type"] == "session_meta"
      end
      nil
    rescue JSON::ParserError
      nil
    end

    def parse_session(path, session_id, cwd)
      thread = empty_thread(session_id, cwd)
      turns = {}
      first_user_message = nil
      session_created_at = nil

      File.foreach(path) do |line|
        row = JSON.parse(line)
        payload = row["payload"] || {}
        if row["type"] == "session_meta"
          session_created_at ||= payload["timestamp"] || row["timestamp"]
        elsif row["type"] == "event_msg" && payload["type"] == "user_message"
          first_user_message ||= payload["message"] || payload["text"]
        end
        next unless row["type"] == "event_msg"
        next unless payload["turn_id"]

        turn_id = payload.fetch("turn_id").to_s
        turn = turns[turn_id] ||= {
          "identity" => turn_identity(session_id, turn_id),
          "turn_id" => turn_id,
          "started_at" => nil,
          "stopped_at" => nil,
          "duration_seconds" => nil,
          "terminal_event" => nil,
          "source" => "session_history"
        }
        case payload["type"]
        when "task_started"
          turn["started_at"] = earlier_timestamp(turn["started_at"], row.fetch("timestamp"))
        when *TERMINAL_EVENTS
          turn["stopped_at"] = later_timestamp(turn["stopped_at"], row.fetch("timestamp"))
          turn["terminal_event"] = payload["type"]
        end
      end

      turns.each_value do |turn|
        next unless turn["started_at"] && turn["stopped_at"]

        turn["duration_seconds"] = [(Time.iso8601(turn.fetch("stopped_at")) - Time.iso8601(turn.fetch("started_at"))).round, 0].max
      end
      starts = turns.values.map { |turn| turn["started_at"] }.compact
      thread["created_at"] = normalize_timestamp(session_created_at || starts.min)
      thread["title"] = summarize_title(first_user_message)
      thread["turns"] = turns.values.select { |turn| turn["started_at"] }.sort_by { |turn| [turn.fetch("started_at"), turn.fetch("turn_id")] }
      thread
    rescue JSON::ParserError => e
      raise ArgumentError, "invalid Codex session #{path}: #{e.message}"
    end

    def summarize_title(message)
      text = message.to_s
      request_marker = text.match(/## My request(?: for Codex)?:\s*/i)
      text = text[request_marker.end(0)..] if request_marker
      text = text.gsub(/\[([^\]]+)\]\(https?:\/\/[^)]+\)/, '\\1')
      text = text.gsub(%r{https?://\S+}, " ").gsub(%r{/var/folders/\S+}, " ").gsub(/\s+/, " ").strip
      return "Без названия" if text.empty?

      text.length > 140 ? "#{text[0, 137]}..." : text
    end

    def empty_thread(session_id, cwd)
      {
        "thread_id" => session_id,
        "url" => "codex://threads/#{session_id}",
        "cwd" => cwd,
        "title" => "Без названия",
        "created_at" => nil,
        "turns" => []
      }
    end

    def merge_thread!(threads, incoming)
      existing = threads[incoming.fetch("thread_id")]
      unless existing
        threads[incoming.fetch("thread_id")] = incoming
        return
      end

      existing["title"] = incoming["title"] unless incoming["title"] == "Без названия"
      existing["created_at"] = earlier_timestamp(existing["created_at"], incoming["created_at"])
      incoming.fetch("turns").each { |turn| merge_turn!(existing.fetch("turns"), turn) }
      existing["turns"].sort_by! { |turn| [turn.fetch("started_at"), turn.fetch("turn_id")] }
    end

    def merge_turn!(turns, incoming)
      existing = turns.find { |turn| turn["identity"] == incoming["identity"] }
      unless existing
        turns << incoming
        return
      end

      existing["started_at"] = earlier_timestamp(existing["started_at"], incoming["started_at"])
      existing["stopped_at"] = later_timestamp(existing["stopped_at"], incoming["stopped_at"])
      existing["terminal_event"] = incoming["terminal_event"] if incoming["terminal_event"]
      existing["source"] = incoming["source"] if incoming["source"] == "session_history"
      if existing["started_at"] && existing["stopped_at"]
        existing["duration_seconds"] = [(Time.iso8601(existing.fetch("stopped_at")) - Time.iso8601(existing.fetch("started_at"))).round, 0].max
      end
    end

    def merge_hook_only_turns!(threads, existing_report, project)
      return unless existing_report

      excluded_ids = excluded_thread_ids(project)
      existing_report.fetch("threads", []).each do |thread|
        next if excluded_ids.include?(thread["thread_id"])

        hook_turns = thread.fetch("turns", []).select { |turn| turn["source"] == "hook" }
        next if hook_turns.empty?

        target = threads[thread.fetch("thread_id")] ||= thread.merge("turns" => [])
        hook_turns.each { |turn| merge_turn!(target.fetch("turns"), turn) }
      end
    end

    def threads_by_id(report)
      return {} unless report

      report.fetch("threads", []).to_h { |thread| [thread.fetch("thread_id"), thread] }
    end

    def build_report(project_key, project, threads, refreshed_at:)
      normalized_threads = threads.values.sort_by do |thread|
        [thread["created_at"] || "9999", thread.fetch("thread_id")]
      end
      completed_turns = normalized_threads.flat_map { |thread| thread.fetch("turns") }.select { |turn| turn["duration_seconds"] }
      active_turns = normalized_threads.flat_map { |thread| thread.fetch("turns") }.reject { |turn| turn["duration_seconds"] }
      months = monthly_summary(normalized_threads)
      total_seconds = completed_turns.sum { |turn| turn.fetch("duration_seconds") }

      {
        "schema_version" => SCHEMA_VERSION,
        "project" => project_key,
        "display_name" => project["display_name"] || project_key,
        "timezone" => agent_os_timezone,
        "refreshed_at" => refreshed_at,
        "measurement" => "completed Codex execution turns",
        "scope" => {
          "paths" => all_project_paths(project),
          "included_thread_ids" => included_thread_ids(project),
          "excluded_threads" => excluded_threads(project)
        },
        "summary" => {
          "total_seconds" => total_seconds,
          "thread_count" => normalized_threads.length,
          "completed_turns" => completed_turns.length,
          "active_turns" => active_turns.length,
          "months" => months
        },
        "threads" => normalized_threads
      }
    end

    def monthly_summary(threads)
      buckets = Hash.new do |hash, key|
        hash[key] = { "month" => key, "seconds" => 0, "turn_ids" => [], "thread_ids" => [] }
      end
      threads.each do |thread|
        thread.fetch("turns").each do |turn|
          next unless turn["duration_seconds"]

          split_by_month(Time.iso8601(turn.fetch("started_at")), Time.iso8601(turn.fetch("stopped_at"))).each do |month, seconds|
            bucket = buckets[month]
            bucket["seconds"] += seconds
            bucket["turn_ids"] << turn.fetch("identity")
            bucket["thread_ids"] << thread.fetch("thread_id")
          end
        end
      end
      buckets.values.sort_by { |bucket| bucket.fetch("month") }.map do |bucket|
        {
          "month" => bucket.fetch("month"),
          "seconds" => bucket.fetch("seconds"),
          "turn_count" => bucket.fetch("turn_ids").uniq.length,
          "thread_count" => bucket.fetch("thread_ids").uniq.length
        }
      end
    end

    def split_by_month(start_time, stop_time)
      return {} if stop_time <= start_time

      with_timezone(agent_os_timezone) do
        cursor = start_time
        segments = Hash.new(0)
        while cursor < stop_time
          local = cursor.getlocal
          month = local.strftime("%Y-%m")
          year = local.year + (local.month == 12 ? 1 : 0)
          next_month = local.month == 12 ? 1 : local.month + 1
          boundary = Time.local(year, next_month, 1, 0, 0, 0).utc
          segment_end = [stop_time, boundary].min
          segments[month] += (segment_end - cursor).round
          cursor = segment_end
        end
        segments
      end
    end

    def with_timezone(timezone)
      previous = ENV["TZ"]
      ENV["TZ"] = timezone
      yield
    ensure
      previous.nil? ? ENV.delete("TZ") : ENV["TZ"] = previous
    end

    def write_report!(report)
      FileUtils.mkdir_p(report_root)
      atomic_write(json_path(report.fetch("project")), JSON.pretty_generate(report) + "\n")
      atomic_write(markdown_path(report.fetch("project")), render_markdown(report))
    end

    def render_markdown(report)
      summary = report.fetch("summary")
      month_rows = summary.fetch("months").map do |month|
        "| #{format_month(month.fetch("month"))} | #{format_duration(month.fetch("seconds"))} | #{format_hours(month.fetch("seconds"))} | #{month.fetch("thread_count")} | #{month.fetch("turn_count")} |"
      end
      thread_rows = report.fetch("threads").map do |thread|
        seconds = thread.fetch("turns").sum { |turn| turn["duration_seconds"] || 0 }
        completed = thread.fetch("turns").count { |turn| turn["duration_seconds"] }
        active = thread.fetch("turns").length - completed
        state = active.positive? ? "#{completed} завершено, #{active} активно" : completed.to_s
        "| #{thread["created_at"]&.slice(0, 7) || "—"} | [#{thread.fetch("thread_id")}](#{thread.fetch("url")}) | #{escape_table(thread.fetch("title"))} | #{format_duration(seconds)} | #{state} |"
      end
      excluded = report.dig("scope", "excluded_threads")
      excluded_lines = excluded.empty? ? "- Нет явных исключений." : excluded.map do |entry|
        "- `#{entry.fetch("id")}` — #{entry["reason"] || "исключён из клиентского времени"}"
      end.join("\n")

      <<~MARKDOWN
        # #{report.fetch("display_name")} — отчёт по Codex-времени

        Этот файл генерируется командой `tools/project-time refresh --project #{report.fetch("project")}`. Не редактируйте его вручную.

        ## Сводка для клиента

        | Месяц | Время | Десятичные часы | Треды | Codex-turns |
        | --- | ---: | ---: | ---: | ---: |
        #{month_rows.join("\n")}
        | **Итого** | **#{format_duration(summary.fetch("total_seconds"))}** | **#{format_hours(summary.fetch("total_seconds"))}** | **#{summary.fetch("thread_count")}** | **#{summary.fetch("completed_turns")}** |

        ## Что считается

        - Только интервалы активного выполнения Codex: от точного `task_started`/hook start до `task_complete`, `turn_aborted` или hook stop.
        - Паузы между сообщениями, встречи, Slack, ручная проверка и другая работа вне Codex не входят.
        - Месяц определяется в timezone `#{report.fetch("timezone")}`; интервал на границе месяца делится между месяцами.
        - Один тред может учитываться в нескольких месячных строках, если его turns пересекли границу месяца; в строке «Итого» каждый тред считается один раз.
        - Незавершённые turns не добавляются в часы; сейчас активно: #{summary.fetch("active_turns")}.

        ## Явные исключения

        #{excluded_lines}

        ## Треды

        | Месяц старта | Codex-тред | Начальная тема | Время | Turns |
        | --- | --- | --- | ---: | ---: |
        #{thread_rows.join("\n")}

        Обновлено: `#{report.fetch("refreshed_at")}`.
      MARKDOWN
    end

    def validate_report(report)
      errors = []
      errors << "schema_version must be #{SCHEMA_VERSION}" unless report["schema_version"] == SCHEMA_VERSION
      errors << "project is required" if report["project"].to_s.empty?
      thread_ids = report.fetch("threads", []).map { |thread| thread["thread_id"] }
      errors << "thread IDs must be unique" unless thread_ids.compact.uniq.length == thread_ids.length
      turn_ids = report.fetch("threads", []).flat_map { |thread| thread.fetch("turns", []).map { |turn| turn["identity"] } }
      errors << "turn identities must be unique" unless turn_ids.compact.uniq.length == turn_ids.length
      total = report.fetch("threads", []).sum do |thread|
        thread.fetch("turns", []).sum { |turn| turn["duration_seconds"] || 0 }
      end
      errors << "summary total_seconds is stale" unless total == report.dig("summary", "total_seconds")
      monthly = report.dig("summary", "months").to_a.sum { |month| month.fetch("seconds") }
      errors << "monthly seconds do not equal total_seconds" unless monthly == total
      errors
    end

    def read_report(project_key, required:)
      path = json_path(project_key)
      if !File.file?(path)
        raise ArgumentError, "project time report does not exist: #{project_key}" if required
        return nil
      end
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      raise ArgumentError, "invalid project time report #{project_key}: #{e.message}"
    end

    def normalize_timestamp(value)
      time = if value.nil?
               Time.now
             elsif value.is_a?(Time)
               value
             else
               Time.iso8601(value.to_s)
             end
      time.utc.iso8601(6)
    rescue ArgumentError
      raise ArgumentError, "invalid timestamp: #{value}"
    end

    def earlier_timestamp(left, right)
      return right if left.nil?
      return left if right.nil?

      Time.iso8601(left) <= Time.iso8601(right) ? left : right
    end

    def later_timestamp(left, right)
      return right if left.nil?
      return left if right.nil?

      Time.iso8601(left) >= Time.iso8601(right) ? left : right
    end

    def turn_identity(session_id, turn_id)
      "codex:#{session_id}:#{turn_id}"
    end

    def required_payload(payload, key)
      value = payload[key].to_s
      raise ArgumentError, "#{key} is required" if value.empty?

      value
    end

    def format_duration(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, remaining_seconds = remainder.divmod(60)
      "#{hours} ч #{minutes} мин #{remaining_seconds} с"
    end

    def format_hours(seconds)
      format("%.2f", seconds / 3600.0)
    end

    def format_month(month)
      year, number = month.split("-").map(&:to_i)
      names = %w[январь февраль март апрель май июнь июль август сентябрь октябрь ноябрь декабрь]
      "#{names.fetch(number - 1).capitalize} #{year}"
    end

    def escape_table(value)
      value.to_s.gsub("|", "\\|").gsub(/\s+/, " ").strip
    end

    def json_path(project_key)
      File.join(report_root, "#{project_key}.json")
    end

    def markdown_path(project_key)
      File.join(report_root, "#{project_key}.md")
    end

    def lock_path
      File.join(report_root, ".lock")
    end

    def with_lock
      FileUtils.mkdir_p(report_root)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock.flock(File::LOCK_UN) rescue nil
      end
    end

    def atomic_write(path, content)
      temporary = "#{path}.tmp-#{Process.pid}-#{rand(1_000_000)}"
      File.open(temporary, "w", 0o600) do |file|
        file.write(content)
        file.flush
        file.fsync
      end
      File.rename(temporary, path)
    ensure
      File.delete(temporary) if defined?(temporary) && File.exist?(temporary)
    end
  end
end
