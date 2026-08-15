# frozen_string_literal: true

require "json"
require "open3"
require "rubygems/version"

module AgentOS
  class Updater
    PLUGIN_ID = "agent-os@agent-os"
    TAG_PATTERN = /\Av(\d+(?:\.\d+){0,2})\z/.freeze

    def initialize(source:, remote: "origin", environment: ENV)
      @source = File.expand_path(source)
      @remote = remote
      @environment = environment
      raise ArgumentError, "invalid Git remote name: #{remote}" unless remote.match?(/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/)
    end

    def status(include_plugin: true)
      source_status = inspect_source
      {
        schema_version: 1,
        update_available: source_status.fetch(:update_available),
        source: source_status,
        plugin: include_plugin ? inspect_plugin(source_status) : skipped_plugin,
        app: {
          strategy: "sparkle",
          automatic_checks: true,
          automatic_install: "user-opt-in",
          managed_separately: true
        }
      }
    end

    def apply(include_plugin: true)
      before = status(include_plugin: include_plugin)
      source_status = before.fetch(:source)
      source_updated = source_status.fetch(:update_available) ? update_source(source_status) : false
      plugin_status = include_plugin ? refresh_plugin_if_needed : skipped_plugin
      after_source = inspect_source
      {
        schema_version: 1,
        updated: source_updated || plugin_status.fetch(:updated, false),
        source: after_source,
        plugin: plugin_status,
        app: before.fetch(:app)
      }
    end

    private

    def inspect_source
      manifest = packaged_runtime_manifest
      if manifest
        version = manifest.fetch("version")
        return {
          configured: true,
          path: @source,
          remote: nil,
          remote_url: nil,
          current_sha: nil,
          current_tag: nil,
          current_version: version,
          latest_sha: nil,
          latest_tag: nil,
          latest_version: version,
          update_available: false,
          action: "managed-by-app"
        }
      end

      unless git_repository?
        return unavailable_source("Agent OS runtime is not a Git repository")
      end

      head = git_optional("rev-parse", "--verify", "HEAD")
      return unavailable_source("source checkout has no commits yet") unless head

      remote_url = git_optional("remote", "get-url", @remote)
      return unavailable_source("Git remote #{@remote} is not configured", head: head) unless remote_url

      tags = remote_release_tags
      return unavailable_source("Git remote #{@remote} has no vN.N.N release tags", head: head, remote_url: remote_url) if tags.empty?

      latest = tags.max_by { |item| item.fetch(:version) }
      current_tag = git_optional("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
      current_version = version_from_tag(current_tag)
      update_available = current_version.nil? || latest.fetch(:version) > current_version
      {
        configured: true,
        path: @source,
        remote: @remote,
        remote_url: remote_url,
        current_sha: head,
        current_tag: current_tag,
        current_version: current_version&.to_s,
        latest_sha: latest.fetch(:sha),
        latest_tag: latest.fetch(:tag),
        latest_version: latest.fetch(:version).to_s,
        update_available: update_available,
        action: update_available ? "fast-forward-to-release" : "none"
      }
    end

    def unavailable_source(reason, head: nil, remote_url: nil)
      {
        configured: false,
        path: @source,
        remote: @remote,
        remote_url: remote_url,
        current_sha: head,
        current_tag: nil,
        current_version: nil,
        latest_sha: nil,
        latest_tag: nil,
        latest_version: nil,
        update_available: false,
        action: "none",
        reason: reason
      }
    end

    def git_repository?
      _stdout, _stderr, status = capture("git", "rev-parse", "--git-dir", chdir: @source)
      status.success?
    end

    def remote_release_tags
      stdout, stderr, status = capture("git", "ls-remote", "--tags", @remote, chdir: @source)
      raise ArgumentError, command_error("could not inspect Git release tags", stderr) unless status.success?

      raw = {}
      peeled = {}
      stdout.each_line do |line|
        sha, ref = line.strip.split(/\s+/, 2)
        next unless sha && ref

        if ref.end_with?("^{}")
          peeled[ref.delete_suffix("^{}")] = sha
        else
          raw[ref] = sha
        end
      end

      raw.each_with_object([]) do |(ref, sha), releases|
        tag = ref.delete_prefix("refs/tags/")
        version = version_from_tag(tag)
        next unless version

        releases << { tag: tag, version: version, sha: peeled.fetch(ref, sha) }
      end
    end

    def update_source(source_status)
      dirty = git("status", "--porcelain", "--untracked-files=normal")
      raise ArgumentError, "source checkout has local changes; update was not applied" unless dirty.empty?

      tag = source_status.fetch(:latest_tag)
      git!("fetch", "--no-write-fetch-head", @remote, "refs/tags/#{tag}:refs/tags/#{tag}")
      tag_commit = git("rev-list", "-n", "1", tag)
      head = git("rev-parse", "HEAD")

      if ancestor?(head, tag_commit)
        return false if head == tag_commit

        git!("merge", "--ff-only", tag)
        true
      elsif ancestor?(tag_commit, head)
        false
      else
        raise ArgumentError, "latest release #{tag} diverges from the current checkout; update was not applied"
      end
    end

    def inspect_plugin(source_status)
      codex = find_executable("codex")
      return unavailable_plugin("Codex CLI is not available on PATH") unless codex

      manifest_version = plugin_manifest_version
      installed = installed_plugin(codex)
      refresh_required = !installed.nil? && (source_status.fetch(:update_available) || installed["version"] != manifest_version)
      action = installed.nil? ? "install-separately" : refresh_required ? "refresh-after-core" : "none"
      {
        configured: !installed.nil?,
        installed: !installed.nil?,
        installed_version: installed && installed["version"],
        source_version: manifest_version,
        refresh_required: refresh_required,
        updated: false,
        action: action
      }
    rescue JSON::ParserError => error
      unavailable_plugin("Codex CLI returned invalid JSON: #{error.message}")
    end

    def refresh_plugin_if_needed
      codex = find_executable("codex")
      return unavailable_plugin("Codex CLI is not available on PATH") unless codex

      installed = installed_plugin(codex)
      return unavailable_plugin("Agent OS plugin is not installed") unless installed

      source_version = plugin_manifest_version
      if installed["version"] == source_version
        return {
          configured: true,
          installed: true,
          installed_version: installed["version"],
          source_version: source_version,
          refresh_required: false,
          updated: false,
          action: "none"
        }
      end

      run!(codex, "plugin", "remove", PLUGIN_ID, "--json")
      run!(codex, "plugin", "add", PLUGIN_ID, "--json")
      {
        configured: true,
        installed: true,
        installed_version: source_version,
        source_version: source_version,
        refresh_required: false,
        updated: true,
        action: "refreshed-restart-codex"
      }
    rescue JSON::ParserError => error
      unavailable_plugin("Codex CLI returned invalid JSON: #{error.message}")
    end

    def installed_plugin(codex)
      stdout = run!(codex, "plugin", "list", "--marketplace", "agent-os", "--available", "--json")
      JSON.parse(stdout).fetch("installed").find { |item| item.fetch("pluginId") == PLUGIN_ID }
    end

    def plugin_manifest_version
      path = File.join(@source, "plugins", "agent-os", ".codex-plugin", "plugin.json")
      return JSON.parse(File.read(path)).fetch("version") if File.file?(path)

      runtime_manifest = File.join(@source, ".agent-os-runtime.json")
      raise ArgumentError, "missing Agent OS plugin or runtime manifest under #{@source}" unless File.file?(runtime_manifest)

      JSON.parse(File.read(runtime_manifest)).fetch("plugin_version")
    end

    def packaged_runtime_manifest
      path = File.join(@source, ".agent-os-runtime.json")
      return nil unless File.file?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError, KeyError
      nil
    end

    def unavailable_plugin(reason)
      {
        configured: false,
        installed: false,
        installed_version: nil,
        source_version: plugin_version_available? ? plugin_manifest_version : nil,
        refresh_required: false,
        updated: false,
        action: "none",
        reason: reason
      }
    end

    def skipped_plugin
      {
        configured: false,
        installed: false,
        installed_version: nil,
        source_version: nil,
        refresh_required: false,
        updated: false,
        action: "skipped"
      }
    end

    def plugin_version_available?
      File.file?(File.join(@source, "plugins", "agent-os", ".codex-plugin", "plugin.json")) ||
        File.file?(File.join(@source, ".agent-os-runtime.json"))
    end

    def version_from_tag(tag)
      match = TAG_PATTERN.match(tag.to_s)
      match && Gem::Version.new(match[1])
    end

    def ancestor?(older, newer)
      _stdout, _stderr, status = capture("git", "merge-base", "--is-ancestor", older, newer, chdir: @source)
      status.success?
    end

    def git(*arguments)
      stdout, stderr, status = capture("git", *arguments, chdir: @source)
      raise ArgumentError, command_error("Git command failed", stderr) unless status.success?

      stdout.strip
    end

    def git_optional(*arguments)
      stdout, _stderr, status = capture("git", *arguments, chdir: @source)
      status.success? ? stdout.strip : nil
    end

    def git!(*arguments)
      git(*arguments)
    end

    def run!(executable, *arguments)
      stdout, stderr, status = capture(executable, *arguments, chdir: @source)
      raise ArgumentError, command_error("#{File.basename(executable)} command failed", stderr) unless status.success?

      stdout
    end

    def capture(*command, chdir:)
      Open3.capture3(@environment, *command, chdir: chdir)
    end

    def command_error(prefix, stderr)
      detail = stderr.to_s.strip
      detail.empty? ? prefix : "#{prefix}: #{detail}"
    end

    def find_executable(name)
      @environment.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
        candidate = File.join(directory, name)
        return candidate if File.file?(candidate) && File.executable?(candidate)
      end
      nil
    end
  end
end
