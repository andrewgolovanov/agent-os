# frozen_string_literal: true

require "fileutils"
require "yaml"

module AgentOS
  class SlackMonitorSetup
    MONITOR_KEY = "agent-os-slack-monitor"
    DAYS = %w[MO TU WE TH FR SA SU].freeze
    DEFAULT_DAYS = %w[MO TU WE TH FR].freeze
    DEFAULT_TIMES = %w[10:00 14:00 18:00].freeze

    attr_reader :config_path

    def initialize(source:, home:, timezone:, days: DEFAULT_DAYS, times: DEFAULT_TIMES)
      @source = source
      @home = home
      @timezone = validate_timezone(timezone)
      @days = validate_days(days)
      @times = validate_times(times)
      @config_path = File.join(home, "config", "monitors.yaml")
    end

    def plan(replace: false)
      config = load_config
      desired = desired_monitor
      existing = config.fetch("monitors")[MONITOR_KEY]
      action = if existing.nil?
                 "create"
               elsif existing == desired
                 "preserve"
               elsif replace
                 "replace"
               else
                 "conflict"
               end

      {
        schema_version: 1,
        action: action,
        config_path: config_path,
        monitor_key: MONITOR_KEY,
        schedule: desired.fetch("schedule"),
        existing_schedule: existing.is_a?(Hash) ? existing["schedule"] : nil,
        schedule_managed: false,
        desired_monitor: desired
      }
    end

    def apply(replace: false)
      result = plan(replace: replace)
      if result.fetch(:action) == "conflict"
        raise ArgumentError, "#{MONITOR_KEY} already differs; review the preview and pass --replace to overwrite only that monitor"
      end

      return result.merge(applied: false) if result.fetch(:action) == "preserve"

      config = load_config
      config.fetch("monitors")[MONITOR_KEY] = result.fetch(:desired_monitor)
      atomic_write(config_path, YAML.dump(config))
      FileUtils.mkdir_p(File.join(@home, ".runtime", "dispatcher"), mode: 0o700)
      result.merge(applied: true)
    end

    private

    def load_config
      raise ArgumentError, "missing monitor config: #{config_path}; run agent-os init --apply first" unless File.file?(config_path)

      config = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      raise ArgumentError, "#{config_path} must contain a mapping" unless config.is_a?(Hash)
      raise ArgumentError, "#{config_path} schema_version must be 1" unless config["schema_version"] == 1
      raise ArgumentError, "#{config_path} monitors must be a mapping" unless config["monitors"].is_a?(Hash)

      config
    rescue Psych::SyntaxError => error
      raise ArgumentError, "invalid YAML in #{config_path}: #{error.message.lines.first.strip}"
    end

    def desired_monitor
      template_path = File.join(@source, "config", "examples", "slack-monitor.yaml")
      raise ArgumentError, "missing Slack monitor template: #{template_path}" unless File.file?(template_path)

      template = YAML.safe_load(File.read(template_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      template = replace_placeholders(template)
      monitor = template.fetch("monitors").fetch(MONITOR_KEY)
      monitor.fetch("schedule")["days"] = @days
      monitor.fetch("schedule")["local_times"] = @times
      monitor
    rescue KeyError => error
      raise ArgumentError, "invalid Slack monitor template: missing #{error.key.inspect}"
    rescue Psych::SyntaxError => error
      raise ArgumentError, "invalid Slack monitor template: #{error.message.lines.first.strip}"
    end

    def replace_placeholders(value)
      case value
      when Hash
        value.transform_values { |nested| replace_placeholders(nested) }
      when Array
        value.map { |nested| replace_placeholders(nested) }
      when String
        value
          .gsub("__AGENT_OS_SOURCE__", @source)
          .gsub("__AGENT_OS_HOME__", @home)
          .gsub("__TIMEZONE__", @timezone)
      else
        value
      end
    end

    def validate_timezone(value)
      timezone = value.to_s
      unless timezone.match?(/\A[A-Za-z0-9._+-]+(?:\/[A-Za-z0-9._+-]+)*\z/)
        raise ArgumentError, "timezone must be an IANA-style name such as Europe/Madrid"
      end
      timezone
    end

    def validate_days(values)
      days = Array(values).map { |value| value.to_s.upcase }
      raise ArgumentError, "days cannot be empty" if days.empty?
      invalid = days - DAYS
      raise ArgumentError, "invalid schedule days: #{invalid.join(", ")}" unless invalid.empty?
      raise ArgumentError, "schedule days must be unique" unless days.uniq.length == days.length
      days
    end

    def validate_times(values)
      times = Array(values).map(&:to_s)
      raise ArgumentError, "times cannot be empty" if times.empty?
      invalid = times.reject do |value|
        match = value.match(/\A(\d{2}):(\d{2})\z/)
        match && match[1].to_i.between?(0, 23) && match[2].to_i.between?(0, 59)
      end
      raise ArgumentError, "invalid local times: #{invalid.join(", ")}" unless invalid.empty?
      raise ArgumentError, "local times must be unique" unless times.uniq.length == times.length
      times
    end

    def atomic_write(path, content)
      temporary = "#{path}.tmp-#{Process.pid}"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(content)
        file.flush
        file.fsync
      end
      File.rename(temporary, path)
      File.chmod(0o600, path)
    ensure
      File.delete(temporary) if defined?(temporary) && File.exist?(temporary)
    end
  end
end
