# frozen_string_literal: true

require "json"
require "open3"
require "rubygems/version"

module AgentOS
  class Updater
    PLUGIN_ID = "agent-os@agent-os"
    MARKETPLACE_NAME = "agent-os"
    DEFAULT_MARKETPLACE_SOURCE = "https://github.com/andrewgolovanov/agent-os.git"
    MARKETPLACE_METADATA = ".codex-marketplace-install.json"
    COMMAND_TIMEOUT_SECONDS = 90
    TAG_PATTERN = /\Av(\d+(?:\.\d+){0,2})\z/.freeze

    def initialize(
      source:,
      remote: "origin",
      environment: ENV,
      marketplace_source: DEFAULT_MARKETPLACE_SOURCE,
      command_timeout: COMMAND_TIMEOUT_SECONDS
    )
      @source = File.expand_path(source)
      @remote = remote
      @environment = environment
      @marketplace_source = marketplace_source
      @command_timeout = command_timeout
      raise ArgumentError, "invalid Git remote name: #{remote}" unless remote.match?(/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/)
      raise ArgumentError, "command timeout must be positive" unless command_timeout.positive?
    end

    def status(include_plugin: true)
      source_status = inspect_source
      plugin_status = include_plugin ? inspect_plugin(source_status) : skipped_plugin
      {
        schema_version: 1,
        update_available: source_status.fetch(:update_available) || plugin_status.fetch(:refresh_required, false),
        source: source_status,
        plugin: plugin_status,
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
      after_source = inspect_source
      plugin_status = include_plugin ? refresh_plugin_if_needed(after_source) : skipped_plugin
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
      unless installed
        return unavailable_plugin(
          "Agent OS plugin is not installed",
          source_version: manifest_version,
          action: "install-separately"
        )
      end

      relation = plugin_version_relation(installed["version"], manifest_version)
      if relation == :invalid
        return unavailable_plugin(
          "Installed or bundled Agent OS plugin version is invalid",
          installed: installed,
          source_version: manifest_version,
          action: "manual-update-required"
        )
      end

      refresh_required = source_status.fetch(:update_available) || %i[older same_release_mismatch].include?(relation)
      action = if relation == :newer && !source_status.fetch(:update_available)
                 "installed-newer-than-runtime"
               elsif refresh_required
                 "refresh-after-core"
               else
                 "none"
               end
      status = {
        configured: true,
        installed: true,
        installed_version: installed["version"],
        source_version: manifest_version,
        refresh_required: refresh_required,
        updated: false,
        action: action,
        reason: relation == :newer ? "Installed plugin is newer than this Agent OS runtime and will not be downgraded" : nil
      }

      packaged_runtime_manifest ? status.merge(packaged_plugin_plan(codex, status)) : status
    rescue JSON::ParserError, KeyError, Errno::ENOENT => error
      unavailable_plugin("Codex CLI returned invalid marketplace state: #{error.message}")
    end

    def refresh_plugin_if_needed(source_status)
      codex = find_executable("codex")
      return unavailable_plugin("Codex CLI is not available on PATH") unless codex

      current = inspect_plugin(source_status)
      return current unless current.fetch(:refresh_required, false)

      if packaged_runtime_manifest
        return current unless current.fetch(:action) == "install-packaged-release"

        return refresh_packaged_plugin(codex, current)
      end

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
      begin
        run!(codex, "plugin", "add", PLUGIN_ID, "--json")
      rescue StandardError => error
        rollback_errors = []
        rollback_command(rollback_errors, codex, "plugin", "add", PLUGIN_ID, "--json")
        raise update_failure(error, rollback_errors)
      end
      refreshed = installed_plugin(codex)
      unless refreshed && refreshed["version"] == source_version
        raise ArgumentError, "Codex plugin refresh did not install expected version #{source_version}"
      end
      {
        configured: true,
        installed: true,
        installed_version: source_version,
        source_version: source_version,
        refresh_required: false,
        updated: true,
        action: "refreshed-restart-codex"
      }
    rescue JSON::ParserError, KeyError => error
      unavailable_plugin("Codex CLI returned invalid JSON: #{error.message}")
    end

    def packaged_plugin_plan(codex, status)
      target_ref = packaged_plugin_ref
      marketplace = configured_marketplace(codex)
      source = marketplace&.dig("marketplaceSource", "source")
      source_type = marketplace&.dig("marketplaceSource", "sourceType")
      current_ref = marketplace_reference(marketplace)
      common = {
        marketplace_source: source,
        marketplace_ref: current_ref,
        target_ref: target_ref
      }

      return common if %w[none installed-newer-than-runtime].include?(status.fetch(:action))
      unless marketplace
        return common.merge(
          action: "manual-update-required",
          reason: "The configured Agent OS marketplace is missing"
        )
      end
      unless source_type == "git" && source == @marketplace_source
        return common.merge(
          action: "manual-update-required",
          reason: "Only the official Agent OS Git marketplace can be updated automatically"
        )
      end
      unless version_from_tag(current_ref)
        return common.merge(
          action: "manual-update-required",
          reason: "The Agent OS marketplace is not pinned to a stable release tag"
        )
      end

      common.merge(action: "install-packaged-release", reason: nil)
    end

    def refresh_packaged_plugin(codex, status)
      previous_ref = status.fetch(:marketplace_ref)
      target_ref = status.fetch(:target_ref)
      target_version = status.fetch(:source_version)
      verify_release_ref!(target_ref)

      plugin_removed = false
      marketplace_removed = false
      target_marketplace_added = false
      target_plugin_added = false

      begin
        run!(codex, "plugin", "remove", PLUGIN_ID, "--json")
        plugin_removed = true

        if previous_ref != target_ref
          run!(codex, "plugin", "marketplace", "remove", MARKETPLACE_NAME, "--json")
          marketplace_removed = true
          run!(codex, "plugin", "marketplace", "add", @marketplace_source, "--ref", target_ref, "--json")
          target_marketplace_added = true
        end

        run!(codex, "plugin", "add", PLUGIN_ID, "--json")
        target_plugin_added = true
        refreshed = installed_plugin(codex)
        unless refreshed && refreshed["version"] == target_version
          actual = refreshed && refreshed["version"]
          raise ArgumentError, "Codex installed #{actual || "no plugin"}; expected #{target_version}"
        end
      rescue StandardError => error
        rollback_errors = rollback_packaged_plugin(
          codex,
          previous_ref: previous_ref,
          plugin_removed: plugin_removed,
          marketplace_removed: marketplace_removed,
          target_marketplace_added: target_marketplace_added,
          target_plugin_added: target_plugin_added
        )
        raise update_failure(error, rollback_errors)
      end

      status.merge(
        installed_version: target_version,
        marketplace_ref: target_ref,
        refresh_required: false,
        updated: true,
        action: "refreshed-restart-codex",
        reason: nil
      )
    end

    def rollback_packaged_plugin(codex, previous_ref:, plugin_removed:, marketplace_removed:, target_marketplace_added:, target_plugin_added:)
      errors = []
      rollback_command(errors, codex, "plugin", "remove", PLUGIN_ID, "--json") if target_plugin_added
      if target_marketplace_added
        rollback_command(errors, codex, "plugin", "marketplace", "remove", MARKETPLACE_NAME, "--json")
      end
      if marketplace_removed
        rollback_command(
          errors,
          codex,
          "plugin", "marketplace", "add", @marketplace_source, "--ref", previous_ref, "--json"
        )
      end
      rollback_command(errors, codex, "plugin", "add", PLUGIN_ID, "--json") if plugin_removed
      errors
    end

    def rollback_command(errors, executable, *arguments)
      _stdout, stderr, status = capture(executable, *arguments, chdir: @source)
      return if status.success?

      errors << command_error(arguments.join(" "), stderr)
    end

    def update_failure(error, rollback_errors)
      detail = "Agent OS plugin update failed: #{error.message}"
      detail += if rollback_errors.empty?
                  "; the previous plugin installation was restored"
                else
                  "; rollback also failed: #{rollback_errors.join("; ")}"
                end
      ArgumentError.new(detail)
    end

    def configured_marketplace(codex)
      stdout = run!(codex, "plugin", "marketplace", "list", "--json")
      JSON.parse(stdout).fetch("marketplaces").find { |item| item["name"] == MARKETPLACE_NAME }
    end

    def marketplace_reference(marketplace)
      return nil unless marketplace

      root = marketplace["root"]
      return nil unless root && File.absolute_path(root) == root

      metadata = File.join(root, MARKETPLACE_METADATA)
      if File.file?(metadata)
        reference = JSON.parse(File.read(metadata))["ref_name"]
        return reference unless reference.to_s.empty?
      end

      stdout, _stderr, status = capture(
        "git", "-C", root, "describe", "--tags", "--exact-match", "--match", "v[0-9]*", "HEAD",
        chdir: @source
      )
      status.success? ? stdout.strip : nil
    rescue JSON::ParserError
      stdout, _stderr, status = capture(
        "git", "-C", root, "describe", "--tags", "--exact-match", "--match", "v[0-9]*", "HEAD",
        chdir: @source
      )
      status.success? ? stdout.strip : nil
    end

    def packaged_plugin_ref
      version = packaged_runtime_manifest&.fetch("version")
      tag = "v#{version}"
      raise ArgumentError, "packaged Agent OS runtime has an invalid version" unless version_from_tag(tag)

      tag
    end

    def verify_release_ref!(tag)
      raise ArgumentError, "invalid Agent OS release tag #{tag.inspect}" unless version_from_tag(tag)

      _stdout, stderr, status = capture(
        "git", "ls-remote", "--exit-code", "--tags", @marketplace_source,
        "refs/tags/#{tag}", "refs/tags/#{tag}^{}",
        chdir: @source
      )
      return if status.success?

      raise ArgumentError, command_error("could not verify Agent OS release #{tag}", stderr)
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

    def unavailable_plugin(reason, installed: nil, source_version: nil, action: "none")
      {
        configured: !installed.nil?,
        installed: !installed.nil?,
        installed_version: installed && installed["version"],
        source_version: source_version || (plugin_version_available? ? plugin_manifest_version : nil),
        refresh_required: false,
        updated: false,
        action: action,
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

    def plugin_version_relation(installed, target)
      installed_release = Gem::Version.new(installed.to_s.split("+", 2).first)
      target_release = Gem::Version.new(target.to_s.split("+", 2).first)
      return :older if installed_release < target_release
      return :newer if installed_release > target_release
      return :same if installed == target

      :same_release_mismatch
    rescue ArgumentError
      :invalid
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
      stdout_text = ""
      stderr_text = ""
      process_status = nil
      timed_out = false

      Open3.popen3(@environment, *command, chdir: chdir, pgroup: true) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        stdout_reader = Thread.new { stdout.read }
        stderr_reader = Thread.new { stderr.read }

        unless wait_thread.join(@command_timeout)
          timed_out = true
          terminate_process_group(wait_thread.pid, "TERM")
          unless wait_thread.join(5)
            terminate_process_group(wait_thread.pid, "KILL")
            wait_thread.join
          end
        end

        process_status = wait_thread.value
        stdout_text = stdout_reader.value
        stderr_text = stderr_reader.value
      end

      if timed_out
        timeout_message = "command timed out after #{@command_timeout} seconds"
        stderr_text = [stderr_text.strip, timeout_message].reject(&:empty?).join(": ")
      end
      [stdout_text, stderr_text, process_status]
    end

    def terminate_process_group(pid, signal)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH
      nil
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
