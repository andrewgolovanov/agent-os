# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tempfile"
require "yaml"
require_relative "task_board"

module AgentOS
  class ProjectRegistry
    KEY_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
    SLACK_CHANNEL_ID_PATTERN = /\A[CG][A-Z0-9]+\z/.freeze
    FINISHED_TASK_STATUSES = %w[done cancelled].freeze
    CHANNEL_NAME_PREFIXES = %w[project].freeze
    CHANNEL_NAME_SUFFIXES = %w[int internal client external ext team].freeze
    REPOSITORY_NAME_SUFFIXES = %w[next site website web app frontend backend].freeze

    def initialize(source:, home:)
      @source = File.expand_path(source)
      @home = File.expand_path(home)
      @registry_path = File.join(@home, "config", "projects.yaml")
      @task_board = AgentOS::TaskBoard.new(File.join(@home, "work"))
    end

    def onboard(repository:, key: nil, display_name: nil, slack_channel_ids: [], apply: false)
      repository = verified_repository(repository)
      key = normalized_key(key || File.basename(repository.fetch(:path)))
      display_name = normalized_display_name(display_name, key)
      registry = load_registry

      if (existing = project_for_repository(registry, repository.fetch(:path)))
        project = existing.fetch(:project)
        if legacy_project?(project)
          raise ArgumentError, "project uses obsolete registry metadata; run upgrade-project-registry first"
        end
        key = existing.fetch(:key)
        display_name = project.fetch("display_name")
        reconciliation = slack_reconciliation_plan(
          registry,
          key: key,
          display_name: display_name,
          aliases: project["aliases"],
          selected_channel_ids: slack_channel_ids
        )
        registry_changed = reconciliation.fetch(:selected_channels).any? do |channel|
          current = Array(project["slack_channels"]).find { |entry| entry["id"] == channel.fetch(:id) }
          current.nil? || current["name"] != channel.fetch(:name)
        end
        has_changes = registry_changed || reconciliation.fetch(:task_assignments).any?
        action = has_changes ? (apply ? "reconciled" : "reconcile") : "preserve"
        if apply && has_changes
          update_project_channels(key, reconciliation.fetch(:selected_channels)) if registry_changed
          assign_reconciled_tasks(key, reconciliation.fetch(:task_assignments))
        end
        return result(
          action: action, applied: apply && has_changes, key: key,
          display_name: display_name, root: project_root(project),
          repository: repository, files: registry_changed ? [@registry_path] : [],
          reconciliation: reconciliation,
          reason: has_changes ? "selected Slack channels are linked without changing repository state" : "repository is already registered"
        )
      end

      projects = registry.fetch("projects")
      if projects.key?(key)
        raise ArgumentError, "project key #{key.inspect} already belongs to another repository"
      end

      reconciliation = slack_reconciliation_plan(
        registry,
        key: key,
        display_name: display_name,
        aliases: [],
        selected_channel_ids: slack_channel_ids
      )

      files = [@registry_path]
      unless apply
        return result(
          action: "create", applied: false, key: key, display_name: display_name,
          root: repository.fetch(:path), repository: repository, files: files,
          reconciliation: reconciliation,
          reason: "preview only"
        )
      end

      update_registry(
        key,
        project_entry(
          display_name: display_name,
          repository: repository,
          slack_channels: reconciliation.fetch(:selected_channels)
        )
      )
      assign_reconciled_tasks(key, reconciliation.fetch(:task_assignments))
      result(
        action: "created", applied: true, key: key, display_name: display_name,
        root: repository.fetch(:path), repository: repository, files: files,
        reconciliation: reconciliation,
        reason: "project registered and selected Slack channels linked without moving or changing the repository"
      )
    end

    def upgrade_registry(apply: false)
      registry = load_registry
      candidates = registry.fetch("projects").each_with_object([]) do |(key, project), items|
        next unless project.is_a?(Hash) && legacy_project?(project)

        upgraded = upgraded_project(project)
        legacy_path = managed_legacy_path(key, project)
        backup = legacy_path && File.directory?(legacy_path) ? legacy_backup_path(key) : nil
        raise ArgumentError, "legacy project backup already exists: #{backup}" if backup && File.exist?(backup)

        items << {
          key: key,
          project: upgraded,
          previous_root: legacy_project_root(project),
          root: upgraded.fetch("root"),
          legacy_path: legacy_path,
          backup: backup
        }
      end

      result = {
        schema_version: 1,
        action: candidates.empty? ? "preserve" : (apply ? "upgraded" : "upgrade"),
        applied: apply && !candidates.empty?,
        projects: candidates.map do |candidate|
          {
            key: candidate.fetch(:key),
            previous_root: candidate.fetch(:previous_root),
            root: candidate.fetch(:root),
            backup: candidate.fetch(:backup)
          }
        end,
        files: candidates.empty? ? [] : [@registry_path],
        reason: candidates.empty? ? "registry already uses root and repositories only" : "legacy project metadata is replaced by registry-only roots"
      }
      return result unless apply && !candidates.empty?

      apply_registry_upgrade!(candidates)
      result
    end

    def relink(repository:, key:, repository_id: nil, apply: false)
      repository = verified_repository(repository)
      key = normalized_key(key)
      registry = load_registry
      project = registry.fetch("projects").fetch(key) do
        raise ArgumentError, "project key #{key.inspect} is not registered"
      end
      raise ArgumentError, "project entry must be a mapping" unless project.is_a?(Hash)
      if legacy_project?(project)
        raise ArgumentError, "project uses obsolete registry metadata; run upgrade-project-registry first"
      end

      registered = Array(project["repositories"])
      entry = if repository_id.to_s.empty?
                raise ArgumentError, "repository id is required for a multi-repository project" unless registered.length == 1
                registered.first
              else
                registered.find { |item| item.is_a?(Hash) && item["id"] == repository_id }
              end
      raise ArgumentError, "registered repository was not found" unless entry.is_a?(Hash)

      previous_path = File.expand_path(entry.fetch("path"))
      if same_path?(previous_path, repository.fetch(:path))
        return relink_result(key, project, entry, repository, previous_path, apply: false, action: "preserve")
      end

      other = project_for_repository(registry, repository.fetch(:path))
      if other && other.fetch(:key) != key
        raise ArgumentError, "repository is already registered as #{other.fetch(:key)}"
      end
      verify_repository_identity!(entry, previous_path, repository)

      unless apply
        return relink_result(key, project, entry, repository, previous_path, apply: false, action: "replace")
      end

      relink_registry!(key, entry.fetch("id"), previous_path, repository)
      updated = load_registry.fetch("projects").fetch(key)
      updated_entry = updated.fetch("repositories").find { |item| item.fetch("id") == entry.fetch("id") }
      relink_result(key, updated, updated_entry, repository, previous_path, apply: true, action: "relinked")
    end

    private

    def apply_registry_upgrade!(candidates)
      moved = []
      lock_path = File.join(@home, ".runtime", "projects.lock")
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        registry = load_registry

        candidates.each do |candidate|
          key = candidate.fetch(:key)
          current = registry.fetch("projects").fetch(key)
          raise ArgumentError, "project #{key} changed during registry upgrade" unless legacy_project?(current)

          if (source = candidate.fetch(:legacy_path)) && File.directory?(source)
            backup = candidate.fetch(:backup)
            raise ArgumentError, "legacy project backup already exists: #{backup}" if File.exist?(backup)

            FileUtils.mkdir_p(File.dirname(backup))
            File.rename(source, backup)
            moved << [source, backup]
          end
          registry.fetch("projects")[key] = candidate.fetch(:project)
        end

        atomic_write(@registry_path, YAML.dump(registry), mode: 0o600)
      end
    rescue StandardError
      moved.reverse_each do |source, backup|
        File.rename(backup, source) if File.exist?(backup) && !File.exist?(source)
      end
      raise
    end

    def legacy_project?(project)
      project.key?("layout") || project.key?("wrapper") || !project.key?("root")
    end

    def upgraded_project(project)
      repositories = Array(project["repositories"]).map do |entry|
        raise ArgumentError, "registered repository must be a mapping" unless entry.is_a?(Hash)

        verified = verified_repository(entry.fetch("path"))
        normalized = Marshal.load(Marshal.dump(entry))
        normalized["path"] = verified.fetch(:path)
        normalized["primary_branch"] = verified.fetch(:primary_branch) if normalized["primary_branch"].to_s.empty? || normalized["primary_branch"] == "unknown"
        normalized["remotes"] ||= { "origin" => verified.fetch(:remote) } if verified[:remote]
        normalized
      end
      raise ArgumentError, "legacy project must register at least one repository" if repositories.empty?

      upgraded = Marshal.load(Marshal.dump(project))
      upgraded.delete("layout")
      upgraded.delete("wrapper")
      upgraded["root"] = primary_repository_path(repositories)
      upgraded["repositories"] = repositories
      upgraded
    end

    def primary_repository_path(repositories)
      primary = repositories.find { |entry| entry["role"] == "primary" } || repositories.first
      File.expand_path(primary.fetch("path"))
    end

    def managed_legacy_path(key, project)
      return nil unless project["layout"] == "wrapper"

      raw = project["wrapper"].to_s
      return nil if raw.empty?

      path = File.expand_path(raw)
      expected = File.join(@home, "projects", key)
      same_path?(path, expected) ? path : nil
    end

    def legacy_backup_path(key)
      File.join(@home, ".runtime", "legacy-project-backups", key)
    end

    def verified_repository(path)
      raw = path.to_s
      raise ArgumentError, "repository path must be absolute" unless Pathname.new(raw).absolute?
      raise ArgumentError, "repository path cannot be the filesystem root" if File.expand_path(raw) == File::SEPARATOR
      raise ArgumentError, "repository path does not exist: #{raw}" unless File.directory?(raw)

      root = File.realpath(git(raw, "rev-parse", "--show-toplevel"))
      head = git(root, "rev-parse", "HEAD")
      branch = git_optional(root, "branch", "--show-current")
      remote = git_optional(root, "remote", "get-url", "origin")
      primary_branch = git_optional(root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")&.delete_prefix("origin/")
      status = git(root, "status", "--short", "--branch")

      {
        path: root,
        id: normalized_key(File.basename(root)),
        role: "primary",
        source_of_truth: "unknown",
        primary_branch: primary_branch.to_s.empty? ? "unknown" : primary_branch,
        remote: remote.to_s.empty? ? nil : remote,
        checked_out_branch: branch.to_s.empty? ? nil : branch,
        head: head,
        clean: status.lines.drop(1).empty?,
        status: status
      }
    end

    def load_registry
      raise ArgumentError, "missing project registry: #{@registry_path}" unless File.file?(@registry_path)

      payload = YAML.safe_load(File.read(@registry_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      raise ArgumentError, "project registry must be a mapping" unless payload.is_a?(Hash)
      raise ArgumentError, "project registry schema_version must be 1" unless payload["schema_version"] == 1
      raise ArgumentError, "project registry projects must be a mapping" unless payload["projects"].is_a?(Hash)

      payload
    rescue Psych::SyntaxError => error
      raise ArgumentError, "invalid project registry: #{error.message.lines.first.strip}"
    end

    def project_for_repository(registry, path)
      expanded = File.expand_path(path)
      registry.fetch("projects").each do |key, project|
        next unless project.is_a?(Hash)

        repositories = Array(project["repositories"])
        if repositories.any? { |item| item.is_a?(Hash) && registered_repository_path(item["path"]) == expanded }
          return { key: key, project: project }
        end
      end
      nil
    end

    def registered_repository_path(path)
      expanded = File.expand_path(path.to_s)
      return expanded unless File.directory?(expanded)

      root = git_optional(expanded, "rev-parse", "--show-toplevel")
      root.to_s.empty? ? expanded : File.expand_path(root)
    end

    def project_entry(display_name:, repository:, slack_channels: [])
      entry = {
        "display_name" => display_name,
        "status" => "active",
        "aliases" => [],
        "root" => repository.fetch(:path),
        "slack_channels" => serialized_slack_channels(slack_channels),
        "repositories" => [
          {
            "id" => repository.fetch(:id),
            "path" => repository.fetch(:path),
            "role" => repository.fetch(:role),
            "source_of_truth" => repository.fetch(:source_of_truth),
            "primary_branch" => repository.fetch(:primary_branch)
          }
        ]
      }
      remote = repository[:remote]
      entry.fetch("repositories").first["remotes"] = { "origin" => remote } if remote
      entry
    end

    def slack_reconciliation_plan(registry, key:, display_name:, aliases:, selected_channel_ids:)
      suggestions = slack_channel_suggestions(
        registry,
        key: key,
        display_name: display_name,
        aliases: Array(aliases)
      )
      selected_ids = Array(selected_channel_ids).map { |value| normalized_slack_channel_id(value) }.uniq
      suggestions_by_id = suggestions.to_h { |channel| [channel.fetch(:id), channel] }
      unknown_ids = selected_ids.reject { |channel_id| suggestions_by_id.key?(channel_id) }
      unless unknown_ids.empty?
        raise ArgumentError,
              "Slack channels are not safe onboarding suggestions: #{unknown_ids.join(", ")}; preview again and select exact suggested IDs"
      end

      selected_channels = selected_ids.map { |channel_id| suggestions_by_id.fetch(channel_id) }
      task_assignments = selected_channels.flat_map do |channel|
        channel.fetch(:assign_task_ids).map do |task_id|
          { task_id: task_id, channel_id: channel.fetch(:id), label_key: channel.fetch(:key) }
        end
      end.uniq { |assignment| assignment.fetch(:task_id) }
      {
        suggested_channels: suggestions,
        selected_channels: selected_channels,
        task_assignments: task_assignments
      }
    end

    def slack_channel_suggestions(registry, key:, display_name:, aliases:)
      identity_owners = Hash.new { |hash, identity| hash[identity] = [] }
      registry.fetch("projects").each do |project_key, project|
        next unless project.is_a?(Hash)

        project_identity_variants(
          project_key,
          project.fetch("display_name", project_key),
          Array(project["aliases"])
        ).each { |identity| identity_owners[identity] << project_key }
      end
      project_identity_variants(key, display_name, aliases).each { |identity| identity_owners[identity] << key }
      identity_owners.each_value(&:uniq!)

      mapped_owners = Hash.new { |hash, channel_id| hash[channel_id] = [] }
      registry.fetch("projects").each do |project_key, project|
        Array(project["slack_channels"]).each do |channel|
          mapped_owners[channel["id"].to_s.upcase] << project_key if channel.is_a?(Hash)
        end
      end

      channels = {}
      @task_board.tasks.each do |task|
        next if FINISHED_TASK_STATUSES.include?(task.fetch("status"))

        Array(task["labels"]).each do |label|
          next unless label.is_a?(Hash) && label["kind"] == "slack_channel"

          channel_id = label.fetch("key").delete_prefix("slack:").upcase
          entry = channels[channel_id] ||= {
            id: channel_id,
            key: "slack:#{channel_id}",
            name: label.fetch("name"),
            task_ids: [],
            assign_task_ids: [],
            task_projects: []
          }
          entry[:name] = label.fetch("name")
          entry[:task_ids] << task.fetch("id")
          entry[:task_projects] |= Array(task["projects"])
          entry[:assign_task_ids] << task.fetch("id") if Array(task["projects"]).empty?
        end
      end

      channels.values.each_with_object([]) do |channel, suggestions|
        stem = normalized_channel_project_name(channel.fetch(:name))
        next if stem.empty? || identity_owners.fetch(stem, []).uniq != [key]
        next unless (mapped_owners.fetch(channel.fetch(:id), []).uniq - [key]).empty?
        next unless (channel.fetch(:task_projects) - [key]).empty?

        suggestion = channel.merge(
          task_ids: channel.fetch(:task_ids).uniq.sort,
          assign_task_ids: channel.fetch(:assign_task_ids).uniq.sort,
          already_mapped: mapped_owners.fetch(channel.fetch(:id), []).include?(key),
          match: stem
        )
        suggestion.delete(:task_projects)
        suggestions << suggestion
      end.sort_by { |channel| [channel.fetch(:name).downcase, channel.fetch(:id)] }
    end

    def project_identity_variants(key, display_name, aliases)
      [key, display_name, *aliases].flat_map do |value|
        identity = normalized_comparison_name(value)
        variants = [identity]
        parts = identity.split("-")
        variants << parts[0...-1].join("-") if parts.length > 1 && REPOSITORY_NAME_SUFFIXES.include?(parts.last)
        variants
      end.reject(&:empty?).uniq
    end

    def normalized_channel_project_name(value)
      parts = normalized_comparison_name(value.to_s.delete_prefix("#")).split("-")
      parts.shift if CHANNEL_NAME_PREFIXES.include?(parts.first)
      parts.pop while parts.length > 1 && CHANNEL_NAME_SUFFIXES.include?(parts.last)
      parts.join("-")
    end

    def normalized_comparison_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    end

    def normalized_slack_channel_id(value)
      channel_id = value.to_s.delete_prefix("slack:").upcase
      raise ArgumentError, "invalid Slack channel ID: #{value}" unless channel_id.match?(SLACK_CHANNEL_ID_PATTERN)

      channel_id
    end

    def serialized_slack_channels(channels)
      channels.map { |channel| { "id" => channel.fetch(:id), "name" => channel.fetch(:name) } }
              .uniq { |channel| channel.fetch("id") }
              .sort_by { |channel| [channel.fetch("name").downcase, channel.fetch("id")] }
    end

    def update_project_channels(key, channels)
      lock_path = File.join(@home, ".runtime", "projects.lock")
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        registry = load_registry
        project = registry.fetch("projects").fetch(key)
        channels.each do |channel|
          owner = registry.fetch("projects").find do |project_key, candidate|
            project_key != key && Array(candidate["slack_channels"]).any? { |entry| entry["id"] == channel.fetch(:id) }
          end
          raise ArgumentError, "Slack channel #{channel.fetch(:id)} is already mapped to #{owner.first}" if owner
        end

        merged = Array(project["slack_channels"]).map(&:dup)
        channels.each do |channel|
          existing = merged.find { |entry| entry["id"] == channel.fetch(:id) }
          values = { "id" => channel.fetch(:id), "name" => channel.fetch(:name) }
          existing ? existing.replace(values) : merged << values
        end
        project["slack_channels"] = merged
          .uniq { |channel| channel.fetch("id") }
          .sort_by { |channel| [channel.fetch("name").downcase, channel.fetch("id")] }
        atomic_write(@registry_path, YAML.dump(registry), mode: 0o600)
      end
    end

    def assign_reconciled_tasks(key, assignments)
      task_ids = assignments.map { |assignment| assignment.fetch(:task_id) }.uniq
      tasks = task_ids.map { |task_id| @task_board.read_task(task_id) }
      tasks.each do |task|
        raise ArgumentError, "cannot reconcile finished outcome #{task.fetch("id")}" if FINISHED_TASK_STATUSES.include?(task.fetch("status"))
        raise ArgumentError, "cannot replace existing project attribution for #{task.fetch("id")}" unless Array(task["projects"]).empty?
      end
      tasks.each { |task| @task_board.update(task.fetch("id"), "projects" => [key]) }
      task_ids
    end

    def project_root(project)
      File.expand_path(project.fetch("root"))
    end

    def legacy_project_root(project)
      root = project["root"] || project["wrapper"]
      root ||= Array(project["repositories"]).find { |entry| entry.is_a?(Hash) && entry["role"] == "primary" }&.dig("path")
      root ||= Array(project["repositories"]).find { |entry| entry.is_a?(Hash) }&.dig("path")
      root && File.expand_path(root)
    end

    def verify_repository_identity!(entry, previous_path, repository)
      remotes = entry["remotes"].is_a?(Hash) ? entry["remotes"].values : []
      if remotes.empty? && File.directory?(previous_path)
        previous_remote = git_optional(previous_path, "remote", "get-url", "origin")
        remotes << previous_remote unless previous_remote.to_s.empty?
      end
      expected = remotes.map { |remote| normalized_remote(remote) }.compact
      actual = normalized_remote(repository[:remote])
      raise ArgumentError, "cannot verify repository identity because the registered entry has no remote" if expected.empty?
      return if actual && expected.include?(actual)

      raise ArgumentError, "repository remote does not match the registered project"
    end

    def normalized_remote(value)
      remote = value.to_s.strip
      return nil if remote.empty?

      remote = remote.sub(/\Agit@github\.com:/, "https://github.com/")
      remote = remote.sub(/\Assh:\/\/git@github\.com\//, "https://github.com/")
      remote.delete_suffix(".git").delete_suffix("/").downcase
    end

    def relink_registry!(key, repository_id, previous_path, repository)
      lock_path = File.join(@home, ".runtime", "projects.lock")
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        registry = load_registry
        project = registry.fetch("projects").fetch(key)
        entry = project.fetch("repositories").find { |item| item.fetch("id") == repository_id }
        raise ArgumentError, "registered repository changed during relink" unless same_path?(entry.fetch("path"), previous_path)

        project["root"] = repository.fetch(:path) if same_path?(project.fetch("root"), previous_path)
        entry["path"] = repository.fetch(:path)
        entry["remotes"] ||= { "origin" => repository.fetch(:remote) } if repository[:remote]
        atomic_write(@registry_path, YAML.dump(registry), mode: 0o600)
      end
    end

    def update_registry(key, entry)
      lock_path = File.join(@home, ".runtime", "projects.lock")
      FileUtils.mkdir_p(File.dirname(lock_path))
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        registry = load_registry
        raise ArgumentError, "project key #{key.inspect} was registered concurrently" if registry.fetch("projects").key?(key)

        registry.fetch("projects")[key] = entry
        atomic_write(@registry_path, YAML.dump(registry), mode: 0o600)
      end
    end

    def atomic_write(path, content, mode:)
      temporary = Tempfile.new([".#{File.basename(path)}", ".tmp"], File.dirname(path))
      begin
        temporary.chmod(mode)
        temporary.write(content)
        temporary.flush
        temporary.fsync
        temporary.close
        File.rename(temporary.path, path)
      ensure
        temporary.close! rescue nil
      end
    end

    def normalized_key(value)
      key = value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      raise ArgumentError, "project key must use lowercase kebab-case" unless key.match?(KEY_PATTERN)

      key
    end

    def normalized_display_name(value, key)
      name = value.to_s.strip
      name = key.split("-").map(&:capitalize).join(" ") if name.empty?
      raise ArgumentError, "display name cannot be empty" if name.empty?

      name
    end

    def same_path?(left, right)
      left_path = File.expand_path(left)
      right_path = File.expand_path(right)
      left_path = File.realpath(left_path) if File.exist?(left_path)
      right_path = File.realpath(right_path) if File.exist?(right_path)
      left_path == right_path
    end

    def git(directory, *arguments)
      stdout, stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      raise ArgumentError, stderr.strip.empty? ? "Git command failed" : stderr.strip unless status.success?

      stdout.strip
    end

    def git_optional(directory, *arguments)
      stdout, _stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      status.success? ? stdout.strip : nil
    end

    def result(action:, applied:, key:, display_name:, root:, repository:, files:, reconciliation:, reason:)
      {
        schema_version: 1,
        action: action,
        applied: applied,
        project: { key: key, display_name: display_name, root: root },
        repository: repository,
        files: files,
        reconciliation: reconciliation,
        unchanged: [repository.fetch(:path)],
        reason: reason
      }
    end

    def relink_result(key, project, entry, repository, previous_path, apply:, action:)
      {
        schema_version: 1,
        action: action,
        applied: apply && action == "relinked",
        project: { key: key, display_name: project.fetch("display_name"), root: project_root(project) },
        repository: repository.merge(id: entry.fetch("id")),
        previous_path: previous_path,
        files: action == "preserve" ? [] : [@registry_path],
        reason: action == "preserve" ? "repository path is already current" : "registry metadata only; repository files and Git state are unchanged"
      }
    end
  end
end
