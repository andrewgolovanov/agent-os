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

    def sync(directories: nil, repositories: nil, apply: false)
      inputs = [*Array(directories), *Array(repositories)].map(&:to_s).reject(&:empty?).uniq
      raise ArgumentError, "at least one project directory candidate is required" if inputs.empty?

      normalized = []
      skipped = []

      inputs.each do |input|
        normalized << normalize_candidate(input)
      rescue ArgumentError => error
        skipped << skipped_entry(input, "ineligible", error.message)
      end

      candidates = []
      identities = {}
      normalized.sort_by { |candidate| candidate.fetch(:root).length }.each do |candidate|
        input = candidate.fetch(:input)
        identity = candidate.fetch(:identity)
        if (existing = identities[identity])
          skipped << skipped_entry(input, "duplicate", "same project as #{existing}")
          next
        end
        if (parent = candidates.find { |item| descendant_path?(candidate.fetch(:root), item.fetch(:root)) })
          skipped << skipped_entry(input, "duplicate", "nested inside project #{parent.fetch(:root)}")
          next
        end

        identities[identity] = candidate.fetch(:root)
        candidates << candidate
      end

      projects = candidates.each_with_object([]) do |candidate, items|
        items << synchronize_candidate(candidate, apply: apply)
      rescue ArgumentError => error
        skipped << skipped_entry(candidate.fetch(:input), "conflict", error.message, root: candidate.fetch(:root))
      end

      {
        schema_version: 1,
        applied: apply,
        discovered_count: inputs.length,
        eligible_count: candidates.length,
        registered_count: projects.count { |project| project.fetch(:action) == "created" },
        enriched_count: projects.count { |project| project.fetch(:action) == "enriched" },
        refreshed_count: projects.count { |project| project.fetch(:action) == "refreshed" },
        preserved_count: projects.count { |project| project.fetch(:action) == "preserve" },
        skipped_count: skipped.length,
        projects: projects,
        skipped: skipped
      }
    end

    private

    def synchronize_candidate(candidate, apply:)
      preview = @registry.sync_local_project(root: candidate.fetch(:root))
      outcome = if apply && %w[create enrich refresh].include?(preview.fetch(:action))
                  @registry.sync_local_project(root: candidate.fetch(:root), apply: true)
                else
                  preview
                end
      {
        input: candidate.fetch(:input),
        root: outcome.dig(:project, :root),
        repository: outcome.dig(:repository, :path),
        project_key: outcome.dig(:project, :key),
        action: outcome.fetch(:action),
        applied: outcome.fetch(:applied),
        reason: outcome.fetch(:reason)
      }.compact
    end

    def normalize_candidate(input)
      raise ArgumentError, "project directory must be absolute" unless Pathname.new(input).absolute?
      raise ArgumentError, "project directory cannot be the filesystem root" if File.expand_path(input) == File::SEPARATOR
      raise ArgumentError, "project directory does not exist: #{input}" unless File.directory?(input)

      directory = File.realpath(input)
      private_home = File.directory?(@home) ? File.realpath(@home) : File.expand_path(@home)
      if descendant_path?(directory, private_home)
        raise ArgumentError, "Agent OS private home is operational state, not a project root"
      end
      raise ArgumentError, "transient Codex directory is not a durable project root" if transient_worktree?(directory) && !git_root(directory)

      root = git_root(directory) || directory
      root = durable_worktree(root) if transient_worktree?(root)

      if (registered = registered_project_containing(root))
        return {
          input: input,
          root: registered.fetch(:root),
          identity: "registered:#{registered.fetch(:key)}"
        }
      end

      overlapping = registered_project_inside(root)
      if overlapping
        raise ArgumentError, "project directory contains registered project #{overlapping.fetch(:key)} at #{overlapping.fetch(:root)}"
      end

      remote = repository_with_head?(root) ? git_optional(root, "remote", "get-url", "origin") : nil
      identity = normalized_remote(remote) || "path:#{root}"
      { input: input, root: root, identity: identity }
    end

    def registered_project_containing(path)
      registered_projects.select { |project| descendant_path?(path, project.fetch(:root)) }
                         .max_by { |project| project.fetch(:root).length }
    end

    def registered_project_inside(path)
      registered_projects.find do |project|
        project.fetch(:root) != path && descendant_path?(project.fetch(:root), path)
      end
    end

    def registered_projects
      registry_path = File.join(@home, "config", "projects.yaml")
      payload = YAML.safe_load(File.read(registry_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      payload.fetch("projects").each_with_object([]) do |(key, project), projects|
        next unless project.is_a?(Hash) && project["root"]

        path = File.expand_path(project.fetch("root"))
        path = File.realpath(path) if File.directory?(path)
        projects << { key: key, root: path }
      end
    rescue Errno::ENOENT, Psych::SyntaxError, KeyError
      []
    end

    def descendant_path?(path, root)
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end

    def git_root(directory)
      root = git_optional(directory, "rev-parse", "--show-toplevel")
      root.to_s.empty? ? nil : File.realpath(root)
    end

    def repository_with_head?(root)
      !git_optional(root, "rev-parse", "HEAD").to_s.empty?
    end

    def durable_worktree(root)
      paths = git(root, "worktree", "list", "--porcelain").lines.each_with_object([]) do |line, items|
        next unless line.start_with?("worktree ")

        path = line.delete_prefix("worktree ").strip
        items << File.realpath(path) if File.directory?(path)
      end
      durable = paths.find { |path| !transient_worktree?(path) }
      raise ArgumentError, "transient Codex worktree has no durable project checkout" unless durable

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

    def skipped_entry(input, action, reason, root: nil)
      { input: input, root: root, action: action, reason: reason }.compact
    end

    def git(directory, *arguments)
      stdout, stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      raise ArgumentError, stderr.strip.empty? ? "Git command failed" : stderr.lines.first.strip unless status.success?

      stdout.strip
    end

    def git_optional(directory, *arguments)
      stdout, _stderr, status = Open3.capture3("git", "-C", directory, *arguments)
      status.success? ? stdout.strip : nil
    end
  end
end
