# frozen_string_literal: true

require "open3"
require "pathname"
require "yaml"
require_relative "project_registry"

module AgentOS
  class CodexProjectSync
    TRANSIENT_WORKTREE_FRAGMENT = "#{File::SEPARATOR}.codex#{File::SEPARATOR}worktrees#{File::SEPARATOR}"

    def initialize(source:, home:, registry: nil)
      @source = File.expand_path(source)
      @home = File.expand_path(home)
      @registry = registry || AgentOS::ProjectRegistry.new(source: @source, home: @home)
    end

    def sync(repositories:, apply: false)
      inputs = Array(repositories).map(&:to_s).reject(&:empty?).uniq
      raise ArgumentError, "at least one repository candidate is required" if inputs.empty?

      candidates = []
      skipped = []
      identities = {}

      inputs.each do |input|
        candidate = normalize_candidate(input)
        identity = candidate.fetch(:identity)
        if (existing = identities[identity])
          skipped << skipped_entry(input, "duplicate", "same repository as #{existing}")
          next
        end

        identities[identity] = candidate.fetch(:path)
        candidates << candidate
      rescue ArgumentError => error
        skipped << skipped_entry(input, "ineligible", error.message)
      end

      projects = candidates.each_with_object([]) do |candidate, items|
        items << synchronize_candidate(candidate, apply: apply)
      rescue ArgumentError => error
        skipped << skipped_entry(candidate.fetch(:input), "conflict", error.message, repository: candidate.fetch(:path))
      end

      {
        schema_version: 1,
        applied: apply,
        discovered_count: inputs.length,
        eligible_count: candidates.length,
        registered_count: projects.count { |project| project.fetch(:action) == "created" },
        preserved_count: projects.count { |project| project.fetch(:action) == "preserve" },
        skipped_count: skipped.length,
        projects: projects,
        skipped: skipped
      }
    end

    private

    def synchronize_candidate(candidate, apply:)
      if (registered = candidate[:registered])
        return {
          input: candidate.fetch(:input),
          repository: registered.fetch(:repository),
          project_key: registered.fetch(:key),
          action: "preserve",
          applied: false,
          reason: "repository is already registered"
        }
      end

      preview = @registry.onboard(repository: candidate.fetch(:path))
      outcome = if apply && preview.fetch(:action) == "create"
                  @registry.onboard(repository: candidate.fetch(:path), apply: true)
                else
                  preview
                end
      {
        input: candidate.fetch(:input),
        repository: outcome.dig(:repository, :path),
        project_key: outcome.dig(:project, :key),
        action: outcome.fetch(:action),
        applied: outcome.fetch(:applied),
        reason: outcome.fetch(:reason)
      }
    end

    def normalize_candidate(input)
      raise ArgumentError, "repository path must be absolute" unless Pathname.new(input).absolute?
      raise ArgumentError, "repository path cannot be the filesystem root" if File.expand_path(input) == File::SEPARATOR
      raise ArgumentError, "repository path does not exist: #{input}" unless File.directory?(input)

      root = File.realpath(git(input, "rev-parse", "--show-toplevel"))
      root = durable_worktree(root) if transient_worktree?(root)
      if (registered = registered_project(root))
        return { input: input, path: root, identity: "registered:#{registered.fetch(:key)}", registered: registered }
      end

      git(root, "rev-parse", "HEAD")
      remote = git_optional(root, "remote", "get-url", "origin")
      identity = normalized_remote(remote) || "path:#{root}"
      if identity.start_with?("remote:") && (registered = registered_project_for_remote(identity))
        raise ArgumentError,
              "repository origin is already registered as #{registered.fetch(:key)} at #{registered.fetch(:repository)}"
      end
      { input: input, path: root, identity: identity }
    end

    def registered_project(root)
      registry_path = File.join(@home, "config", "projects.yaml")
      payload = YAML.safe_load(File.read(registry_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      payload.fetch("projects").each do |key, project|
        Array(project["repositories"]).each do |repository|
          next unless repository.is_a?(Hash)

          path = File.expand_path(repository.fetch("path"))
          path = File.realpath(path) if File.directory?(path)
          return { key: key, repository: path } if path == root
        end
      end
      nil
    rescue Errno::ENOENT, Psych::SyntaxError, KeyError
      nil
    end

    def registered_project_for_remote(identity)
      registry_path = File.join(@home, "config", "projects.yaml")
      payload = YAML.safe_load(File.read(registry_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      payload.fetch("projects").each do |key, project|
        Array(project["repositories"]).each do |repository|
          next unless repository.is_a?(Hash)

          remotes = repository["remotes"].is_a?(Hash) ? repository.fetch("remotes").values : []
          next unless remotes.any? { |remote| normalized_remote(remote) == identity }

          return { key: key, repository: File.expand_path(repository.fetch("path")) }
        end
      end
      nil
    rescue Errno::ENOENT, Psych::SyntaxError, KeyError
      nil
    end

    def durable_worktree(root)
      paths = git(root, "worktree", "list", "--porcelain").lines.each_with_object([]) do |line, items|
        next unless line.start_with?("worktree ")

        path = line.delete_prefix("worktree ").strip
        items << File.realpath(path) if File.directory?(path)
      end
      durable = paths.find { |path| !transient_worktree?(path) }
      raise ArgumentError, "transient Codex worktree has no durable repository checkout" unless durable

      durable
    end

    def transient_worktree?(path)
      File.expand_path(path).include?(TRANSIENT_WORKTREE_FRAGMENT)
    end

    def normalized_remote(value)
      remote = value.to_s.strip
      return nil if remote.empty?

      remote = remote.sub(/\Agit@github\.com:/, "https://github.com/")
      remote = remote.sub(/\Assh:\/\/git@github\.com\//, "https://github.com/")
      "remote:#{remote.delete_suffix(".git").delete_suffix("/").downcase}"
    end

    def skipped_entry(input, action, reason, repository: nil)
      { input: input, repository: repository, action: action, reason: reason }.compact
    end

    def git(directory, *arguments)
      stdout, stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      raise ArgumentError, stderr.strip.empty? ? "directory is not an eligible Git repository" : stderr.lines.first.strip unless status.success?

      stdout.strip
    end

    def git_optional(directory, *arguments)
      stdout, _stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      status.success? ? stdout.strip : nil
    end
  end
end
