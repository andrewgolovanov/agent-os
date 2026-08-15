# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tempfile"
require "tmpdir"
require "yaml"

module AgentOS
  class ProjectRegistry
    KEY_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze

    def initialize(source:, home:)
      @source = File.expand_path(source)
      @home = File.expand_path(home)
      @registry_path = File.join(@home, "config", "projects.yaml")
      @template_root = File.join(@source, "templates", "project")
    end

    def onboard(repository:, key: nil, display_name: nil, apply: false)
      repository = verified_repository(repository)
      key = normalized_key(key || File.basename(repository.fetch(:path)))
      display_name = normalized_display_name(display_name, key)
      registry = load_registry

      if (existing = project_for_repository(registry, repository.fetch(:path)))
        return result(
          action: "preserve",
          apply: apply,
          key: existing.fetch(:key),
          display_name: existing.fetch(:project).fetch("display_name"),
          layout: existing.fetch(:project).fetch("layout", "wrapper"),
          wrapper: existing.fetch(:project).fetch("wrapper"),
          repository: repository,
          files: [],
          reason: "repository is already registered"
        )
      end

      projects = registry.fetch("projects")
      if projects.key?(key)
        raise ArgumentError, "project key #{key.inspect} already belongs to another repository"
      end

      wrapper = File.join(@home, "projects", key)
      layout = same_path?(repository.fetch(:path), wrapper) ? "direct-repository" : "wrapper"
      files = [@registry_path]
      files.concat(wrapper_files(wrapper)) if layout == "wrapper"
      entry = project_entry(
        key: key,
        display_name: display_name,
        layout: layout,
        wrapper: wrapper,
        repository: repository
      )

      unless apply
        return result(
          action: "create",
          apply: false,
          key: key,
          display_name: display_name,
          layout: layout,
          wrapper: wrapper,
          repository: repository,
          files: files,
          reason: "preview only"
        )
      end

      validate_destination!(wrapper, layout)
      create_wrapper(wrapper, key, entry, repository) if layout == "wrapper"
      update_registry(key, entry)

      result(
        action: "created",
        apply: true,
        key: key,
        display_name: display_name,
        layout: layout,
        wrapper: wrapper,
        repository: repository,
        files: files,
        reason: "project registered without moving or changing the repository"
      )
    end

    def relink(repository:, key:, repository_id: nil, apply: false)
      repository = verified_repository(repository)
      key = normalized_key(key)
      registry = load_registry
      project = registry.fetch("projects").fetch(key) do
        raise ArgumentError, "project key #{key.inspect} is not registered"
      end
      raise ArgumentError, "project entry must be a mapping" unless project.is_a?(Hash)

      registered = Array(project["repositories"])
      entry = if repository_id.to_s.empty?
                raise ArgumentError, "repository id is required for a multi-repository project" unless registered.length == 1
                registered.first
              else
                registered.find { |item| item.is_a?(Hash) && item["id"] == repository_id }
              end
      raise ArgumentError, "registered repository was not found" unless entry.is_a?(Hash)

      previous_path = File.expand_path(entry.fetch("path"))
      return relink_result(key, project, entry, repository, previous_path, apply: false, action: "preserve", files: []) if same_path?(previous_path, repository.fetch(:path))

      other = project_for_repository(registry, repository.fetch(:path))
      if other && other.fetch(:key) != key
        raise ArgumentError, "repository is already registered as #{other.fetch(:key)}"
      end
      verify_repository_identity!(entry, previous_path, repository)
      files = [@registry_path]
      files.concat(wrapper_metadata_files(project, previous_path)) if project["layout"] == "wrapper"

      unless apply
        return relink_result(key, project, entry, repository, previous_path, apply: false, action: "replace", files: files)
      end

      relink_registry!(key, entry.fetch("id"), previous_path, repository)
      updated = load_registry.fetch("projects").fetch(key)
      updated_entry = updated.fetch("repositories").find { |item| item.fetch("id") == entry.fetch("id") }
      relink_result(key, updated, updated_entry, repository, previous_path, apply: true, action: "relinked", files: files)
    end

    private

    def verified_repository(path)
      raw = path.to_s
      raise ArgumentError, "repository path must be absolute" unless Pathname.new(raw).absolute?
      raise ArgumentError, "repository path cannot be the filesystem root" if File.expand_path(raw) == File::SEPARATOR
      raise ArgumentError, "repository path does not exist: #{raw}" unless File.directory?(raw)

      root = git(raw, "rev-parse", "--show-toplevel")
      root = File.realpath(root)
      head = git(root, "rev-parse", "HEAD")
      branch = git_optional(root, "branch", "--show-current")
      remote = git_optional(root, "remote", "get-url", "origin")
      primary_branch = git_optional(root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
        &.delete_prefix("origin/")
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

      payload = YAML.safe_load(
        File.read(@registry_path),
        permitted_classes: [],
        permitted_symbols: [],
        aliases: false
      )
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
        if repositories.any? { |item| item.is_a?(Hash) && File.expand_path(item["path"].to_s) == expanded }
          return { key: key, project: project }
        end
      end
      nil
    end

    def project_entry(key:, display_name:, layout:, wrapper:, repository:)
      entry = {
        "display_name" => display_name,
        "status" => "active",
        "layout" => layout,
        "aliases" => [],
        "wrapper" => wrapper,
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

    def verify_repository_identity!(entry, previous_path, repository)
      remotes = entry["remotes"].is_a?(Hash) ? entry["remotes"].values : []
      if remotes.empty? && File.directory?(previous_path)
        previous_remote = git_optional(previous_path, "remote", "get-url", "origin")
        remotes << previous_remote unless previous_remote.to_s.empty?
      end
      expected = remotes.map { |remote| normalized_remote(remote) }.compact
      actual = normalized_remote(repository[:remote])
      if expected.empty?
        raise ArgumentError, "cannot verify repository identity because the registered entry has no remote"
      end
      return if actual && expected.include?(actual)

      raise ArgumentError, "repository remote does not match the registered project"
    end

    def normalized_remote(value)
      remote = value.to_s.strip
      return nil if remote.empty?
      remote = remote.sub(/\Agit@github\.com:/, "https://github.com/")
      remote = remote.sub(/\Assh:\/\/git@github\.com\//, "https://github.com/")
      remote = remote.delete_suffix(".git").delete_suffix("/")
      remote.downcase
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

        if project["layout"] == "wrapper"
          update_wrapper_metadata!(project, repository_id, previous_path, repository.fetch(:path))
        elsif same_path?(project.fetch("wrapper"), previous_path)
          project["wrapper"] = repository.fetch(:path)
        end
        entry["path"] = repository.fetch(:path)
        entry["remotes"] ||= { "origin" => repository.fetch(:remote) } if repository[:remote]
        atomic_write(@registry_path, YAML.dump(registry), mode: 0o600)
      end
    end

    def wrapper_metadata_files(project, previous_path)
      wrapper = File.expand_path(project.fetch("wrapper"))
      return [] unless wrapper.start_with?("#{@home}/") && File.directory?(wrapper)

      Dir.glob(File.join(wrapper, "**", "*"), File::FNM_DOTMATCH).select do |path|
        File.file?(path) && !File.symlink?(path) && File.read(path).include?(previous_path)
      end
    end

    def update_wrapper_metadata!(project, repository_id, previous_path, repository_path)
      wrapper_metadata_files(project, previous_path).each do |path|
        if File.basename(path) == "project.yaml"
          payload = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
          item = payload.fetch("repositories").find { |candidate| candidate.fetch("id") == repository_id }
          raise ArgumentError, "wrapper repository metadata is missing #{repository_id}" unless item
          item["path"] = repository_path
          atomic_write(path, YAML.dump(payload), mode: 0o600)
        else
          atomic_write(path, File.read(path).gsub(previous_path, repository_path), mode: File.stat(path).mode & 0o777)
        end
      end
    rescue Psych::SyntaxError, KeyError => error
      raise ArgumentError, "invalid wrapper metadata: #{error.message}"
    end

    def relink_result(key, project, entry, repository, previous_path, apply:, action:, files:)
      {
        schema_version: 1,
        action: action,
        applied: apply && action == "relinked",
        project: {
          key: key,
          display_name: project.fetch("display_name"),
          layout: project.fetch("layout", "wrapper"),
          wrapper: project.fetch("wrapper")
        },
        repository: repository.merge(id: entry.fetch("id")),
        previous_path: previous_path,
        files: files,
        reason: action == "preserve" ? "repository path is already current" : "registry metadata only; repository files and Git state are unchanged"
      }
    end

    def create_wrapper(wrapper, key, entry, repository)
      raise ArgumentError, "missing project template: #{@template_root}" unless File.directory?(@template_root)

      parent = File.dirname(wrapper)
      FileUtils.mkdir_p(parent)
      stage = Dir.mktmpdir(".#{File.basename(wrapper)}-", parent)
      begin
        FileUtils.cp_r(Dir.glob(File.join(@template_root, "*"), File::FNM_DOTMATCH).reject { |path| %w[. ..].include?(File.basename(path)) }, stage)
        rewrite_wrapper(stage, key, entry, repository)
        File.rename(stage, wrapper)
        stage = nil
      ensure
        FileUtils.remove_entry(stage) if stage && File.directory?(stage)
      end
    end

    def rewrite_wrapper(root, key, entry, repository)
      display_name = entry.fetch("display_name")
      project_payload = {
        "schema_version" => 1,
        "key" => key,
        "display_name" => display_name,
        "status" => "active",
        "aliases" => [],
        "repositories" => entry.fetch("repositories"),
        "sources" => { "slack" => "unknown", "task_tracker" => "unknown", "design" => "unknown" },
        "deployments" => []
      }
      File.write(File.join(root, "project.yaml"), YAML.dump(project_payload), mode: "w", perm: 0o600)

      replace_text(File.join(root, "AGENTS.md"), "Replace template values during onboarding; do not leave invented facts.", "Verified repository paths are owned by project.yaml and the Agent OS registry; unknown optional facts remain explicit.")
      replace_text(File.join(root, "README.md"), "# Project Name", "# #{display_name}")
      replace_text(
        File.join(root, "README.md"),
        "| `unknown` | `unknown` | `unknown` | `unknown` |",
        "| `#{repository.fetch(:id)}` | `primary` | `unknown` | `#{repository.fetch(:primary_branch)}` |"
      )
      replace_text(File.join(root, "docs", "PROJECT.md"), "# Project Name", "# #{display_name}")
      replace_text(
        File.join(root, "docs", "PROJECT.md"),
        "Unknown.\n\n## Sources of truth",
        "Primary repository: `#{repository.fetch(:path)}`. The repository was registered in place and was not moved.\n\n## Sources of truth"
      )
    end

    def replace_text(path, from, to)
      content = File.read(path)
      raise ArgumentError, "template marker is missing in #{path}: #{from.inspect}" unless content.include?(from)

      File.write(path, content.sub(from, to))
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

    def validate_destination!(wrapper, layout)
      return if layout == "direct-repository"
      return unless File.exist?(wrapper)

      raise ArgumentError, "wrapper path already exists and is not registered: #{wrapper}"
    end

    def wrapper_files(wrapper)
      Dir.glob(File.join(@template_root, "**", "*"), File::FNM_DOTMATCH)
        .select { |path| File.file?(path) }
        .map { |path| File.join(wrapper, path.delete_prefix("#{@template_root}/")) }
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
      File.expand_path(left) == File.expand_path(right)
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

    def result(action:, apply:, key:, display_name:, layout:, wrapper:, repository:, files:, reason:)
      {
        schema_version: 1,
        action: action,
        applied: apply && action == "created",
        project: {
          key: key,
          display_name: display_name,
          layout: layout,
          wrapper: wrapper
        },
        repository: repository,
        files: files,
        unchanged: [repository.fetch(:path)],
        reason: reason
      }
    end
  end
end
