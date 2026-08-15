# frozen_string_literal: true

require "fileutils"
require "find"
require "json"
require "tempfile"
require "tmpdir"
require "yaml"

module AgentOS
  class HomeMigrator
    COPY_DIRECTORIES = %w[config work .runtime].freeze

    def initialize(source:, from:, home:, active_home_pointer:)
      @source = File.expand_path(source)
      @from = File.expand_path(from)
      @home = File.expand_path(home)
      @active_home_pointer = File.expand_path(active_home_pointer)
    end

    def migrate(apply: false)
      registry = validated_registry
      wrappers = wrapper_moves(registry)
      validate_preconditions!(wrappers)

      result = {
        schema_version: 1,
        applied: apply,
        from: @from,
        home: @home,
        source: @source,
        copies: COPY_DIRECTORIES.each_with_object([]) do |name, items|
          source_path = File.join(@from, name)
          next unless File.exist?(source_path)

          items << { from: source_path, to: File.join(@home, name) }
        end + wrappers,
        pointer: { path: @active_home_pointer, from: @from, to: @home },
        rollback: "The previous home is preserved at #{@from}; reactivate it explicitly if rollback is needed."
      }
      return result unless apply

      apply_migration(registry, wrappers)
      result
    end

    private

    def validated_registry
      path = File.join(@from, "config", "projects.yaml")
      raise ArgumentError, "missing project registry: #{path}" unless File.file?(path)

      payload = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
      raise ArgumentError, "project registry must be a mapping" unless payload.is_a?(Hash)
      raise ArgumentError, "project registry schema_version must be 1" unless payload["schema_version"] == 1
      raise ArgumentError, "project registry projects must be a mapping" unless payload["projects"].is_a?(Hash)

      payload
    rescue Psych::SyntaxError => error
      raise ArgumentError, "invalid project registry: #{error.message.lines.first.strip}"
    end

    def validate_preconditions!(wrappers)
      raise ArgumentError, "source and destination homes must differ" if @from == @home
      raise ArgumentError, "destination home already exists: #{@home}" if File.exist?(@home)
      raise ArgumentError, "missing source home: #{@from}" unless File.directory?(@from)
      raise ArgumentError, "invalid Agent OS runtime: #{@source}" unless valid_source_root?(@source)

      current = File.file?(@active_home_pointer) ? File.read(@active_home_pointer).strip : nil
      if current && File.expand_path(current) != @from
        raise ArgumentError, "active home points to #{current}, not the migration source #{@from}"
      end

      required = [
        File.join(@from, "config", "projects.yaml"),
        File.join(@from, "config", "task-bridge.yaml"),
        File.join(@from, "work", "board.json")
      ]
      missing = required.reject { |path| File.file?(path) }
      raise ArgumentError, "source home is incomplete: #{missing.join(", ")}" unless missing.empty?

      inspected = COPY_DIRECTORIES.map { |name| File.join(@from, name) }.select { |path| File.exist?(path) }
      inspected.concat(wrappers.map { |item| item.fetch(:from) })
      inspected.each { |path| reject_symlinks!(path) }
    end

    def wrapper_moves(registry)
      registry.fetch("projects").each_with_object([]) do |(_key, project), items|
        next unless project.is_a?(Hash) && project["layout"] == "wrapper"

        wrapper = File.expand_path(project.fetch("wrapper"))
        next unless inside_home?(wrapper)
        raise ArgumentError, "missing registered wrapper: #{wrapper}" unless File.directory?(wrapper)

        relative = wrapper.delete_prefix("#{@from}/")
        items << { from: wrapper, to: File.join(@home, relative) }
      end
    end

    def apply_migration(registry, wrappers)
      parent = File.dirname(@home)
      FileUtils.mkdir_p(parent)
      stage = Dir.mktmpdir(".#{File.basename(@home)}-migration-", parent)
      begin
        COPY_DIRECTORIES.each do |name|
          source_path = File.join(@from, name)
          next unless File.exist?(source_path)

          FileUtils.cp_r(source_path, File.join(stage, name), preserve: true)
        end
        FileUtils.mkdir_p(File.join(stage, "projects"))
        wrappers.each do |item|
          relative = item.fetch(:to).delete_prefix("#{@home}/")
          destination = File.join(stage, relative)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp_r(item.fetch(:from), destination, preserve: true)
        end

        rewrite_registry!(registry, stage)
        rewrite_monitor_paths!(stage)
        File.write(File.join(stage, "source-path"), "#{@source}\n", mode: "w", perm: 0o600)
        write_migration_record(stage)
        secure_private_state!(stage)
        validate_stage!(stage)
        File.rename(stage, @home)
        stage = nil
        write_pointer(@active_home_pointer, @home)
      ensure
        FileUtils.remove_entry(stage) if stage && File.directory?(stage)
      end
    end

    def rewrite_registry!(registry, stage)
      migrated = Marshal.load(Marshal.dump(registry))
      agent_os = migrated["agent_os"]
      agent_os["root"] = @home if agent_os.is_a?(Hash) && File.expand_path(agent_os["root"].to_s) == @from

      migrated.fetch("projects").each_value do |project|
        next unless project.is_a?(Hash) && project["layout"] == "wrapper"

        wrapper = File.expand_path(project["wrapper"].to_s)
        next unless inside_home?(wrapper)

        relative = wrapper.delete_prefix("#{@from}/")
        project["wrapper"] = File.join(@home, relative)
      end

      path = File.join(stage, "config", "projects.yaml")
      File.write(path, YAML.dump(migrated), mode: "w", perm: 0o600)
    end

    def write_migration_record(stage)
      record = {
        schema_version: 1,
        from: @from,
        home: @home,
        source: @source,
        previous_home_preserved: true
      }
      path = File.join(stage, ".runtime", "home-migration.json")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(record) + "\n", mode: "w", perm: 0o600)
    end

    def rewrite_monitor_paths!(stage)
      path = File.join(stage, "config", "monitors.yaml")
      return unless File.file?(path)

      config = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
      return unless config.is_a?(Hash) && config["monitors"].is_a?(Hash)

      runbook = File.join(@source, "docs", "slack-monitor.md")
      monitor = config.fetch("monitors")["agent-os-slack-monitor"]
      return unless monitor.is_a?(Hash)

      monitor["runbook"] = runbook
      monitor["source_registry"] = File.join(@home, "config", "projects.yaml")
      monitor["task_board_root"] = File.join(@home, "work")
      monitor["runtime_state_root"] = File.join(@home, ".runtime", "dispatcher")
      dashboard = monitor.dig("notifications", "task_board_dashboard")
      dashboard["path"] = File.join(@home, "work", "BOARD.md") if dashboard.is_a?(Hash)
      raise ArgumentError, "packaged runtime is missing Slack monitor runbook: #{runbook}" unless File.file?(runbook)

      File.write(path, YAML.dump(config), mode: "w", perm: 0o600)
    end

    def secure_private_state!(stage)
      File.chmod(0o700, stage)
      Dir.glob(File.join(stage, "config", "*.yaml")).each { |path| File.chmod(0o600, path) }
      File.chmod(0o600, File.join(stage, "source-path"))
    end

    def validate_stage!(stage)
      JSON.parse(File.read(File.join(stage, "work", "board.json")))
      migrated = YAML.safe_load(
        File.read(File.join(stage, "config", "projects.yaml")),
        permitted_classes: [],
        permitted_symbols: [],
        aliases: false
      )
      raise ArgumentError, "migrated project registry is invalid" unless migrated.is_a?(Hash) && migrated["schema_version"] == 1

      migrated.fetch("projects").each_value do |project|
        next unless project.is_a?(Hash) && project["layout"] == "wrapper"

        wrapper = File.expand_path(project.fetch("wrapper"))
        next unless wrapper.start_with?("#{@home}/")

        relative = wrapper.delete_prefix("#{@home}/")
        raise ArgumentError, "migrated wrapper is missing: #{wrapper}" unless File.directory?(File.join(stage, relative))
      end
    rescue JSON::ParserError, Psych::SyntaxError, KeyError => error
      raise ArgumentError, "migrated home validation failed: #{error.message}"
    end

    def reject_symlinks!(root)
      Find.find(root) do |path|
        if File.symlink?(path)
          raise ArgumentError, "migration refuses symbolic links in private state: #{path}"
        end
      end
    end

    def inside_home?(path)
      path.start_with?("#{@from}/")
    end

    def valid_source_root?(path)
      File.executable?(File.join(path, "tools", "task-board")) &&
        File.file?(File.join(path, "config", "examples", "projects.yaml"))
    end

    def write_pointer(path, target)
      FileUtils.mkdir_p(File.dirname(path))
      temporary = Tempfile.new([".#{File.basename(path)}", ".tmp"], File.dirname(path))
      begin
        temporary.chmod(0o600)
        temporary.write("#{target}\n")
        temporary.flush
        temporary.fsync
        temporary.close
        File.rename(temporary.path, path)
      ensure
        temporary.close! rescue nil
      end
    end
  end
end
