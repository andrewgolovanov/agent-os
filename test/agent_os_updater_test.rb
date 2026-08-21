# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../lib/agent_os/updater"

class AgentOSUpdaterTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-updater-")
    @runtime = File.join(@temporary, "runtime")
    @marketplace_root = File.join(@temporary, "marketplace")
    @marketplace_remote = create_release_remote
    @state_path = File.join(@temporary, "codex-state.json")
    @bin = File.join(@temporary, "bin")
    FileUtils.mkdir_p([@runtime, @marketplace_root, @bin])
    write_runtime(version: "0.2.0", plugin_version: "0.2.0+codex.2")
    write_state(
      "marketplace" => {
        "source_type" => "git",
        "source" => @marketplace_remote,
        "ref" => "v0.1.0"
      },
      "marketplace_root" => @marketplace_root,
      "installed_version" => "0.1.0+codex.1",
      "versions" => {
        "v0.1.0" => "0.1.0+codex.1",
        "v0.2.0" => "0.2.0+codex.2",
        "v0.3.0" => "0.3.0+codex.3"
      },
      "commands" => []
    )
    write_marketplace_metadata("v0.1.0")
    write_fake_codex
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_packaged_runtime_plans_matching_tagged_plugin_update
    status = updater.status

    assert_equal true, status.fetch(:update_available)
    assert_equal "managed-by-app", status.dig(:source, :action)
    assert_equal true, status.dig(:plugin, :refresh_required)
    assert_equal "install-packaged-release", status.dig(:plugin, :action)
    assert_equal "v0.1.0", status.dig(:plugin, :marketplace_ref)
    assert_equal "v0.2.0", status.dig(:plugin, :target_ref)
    assert_equal "0.2.0+codex.2", status.dig(:plugin, :source_version)
    assert_empty mutating_commands
  end

  def test_packaged_runtime_re_pins_marketplace_and_installs_matching_plugin
    result = updater.apply
    state = read_state

    assert_equal true, result.fetch(:updated)
    assert_equal true, result.dig(:plugin, :updated)
    assert_equal "refreshed-restart-codex", result.dig(:plugin, :action)
    assert_equal "0.2.0+codex.2", result.dig(:plugin, :installed_version)
    assert_equal "v0.2.0", state.dig("marketplace", "ref")
    assert_equal "0.2.0+codex.2", state.fetch("installed_version")
    assert_equal "v0.2.0", JSON.parse(File.read(metadata_path)).fetch("ref_name")
    assert_equal(
      [
        %w[plugin remove agent-os@agent-os --json],
        %w[plugin marketplace remove agent-os --json],
        ["plugin", "marketplace", "add", @marketplace_remote, "--ref", "v0.2.0", "--json"],
        %w[plugin add agent-os@agent-os --json]
      ],
      mutating_commands.first(4)
    )
  end

  def test_packaged_runtime_restores_previous_tag_when_install_fails
    state = read_state
    state["fail_add_ref"] = "v0.2.0"
    write_state(state)

    error = assert_raises(ArgumentError) { updater.apply }
    restored = read_state

    assert_includes error.message, "previous plugin installation was restored"
    assert_equal "v0.1.0", restored.dig("marketplace", "ref")
    assert_equal "0.1.0+codex.1", restored.fetch("installed_version")
    assert_equal "v0.1.0", JSON.parse(File.read(metadata_path)).fetch("ref_name")
  end

  def test_packaged_runtime_bounds_a_stalled_codex_command_and_rolls_back
    state = read_state
    state["sleep_add_ref"] = "v0.2.0"
    write_state(state)

    error = assert_raises(ArgumentError) { updater(command_timeout: 0.1).apply }
    restored = read_state

    assert_includes error.message, "command timed out after 0.1 seconds"
    assert_includes error.message, "previous plugin installation was restored"
    assert_equal "v0.1.0", restored.dig("marketplace", "ref")
    assert_equal "0.1.0+codex.1", restored.fetch("installed_version")
  end

  def test_packaged_runtime_does_not_downgrade_a_newer_plugin
    state = read_state
    state["installed_version"] = "0.3.0+codex.3"
    state["marketplace"]["ref"] = "v0.3.0"
    write_state(state)
    write_marketplace_metadata("v0.3.0")

    status = updater.status

    assert_equal false, status.fetch(:update_available)
    assert_equal false, status.dig(:plugin, :refresh_required)
    assert_equal "installed-newer-than-runtime", status.dig(:plugin, :action)
    assert_empty mutating_commands
  end

  def test_packaged_runtime_refuses_to_replace_an_untrusted_marketplace
    state = read_state
    state["marketplace"]["source"] = File.join(@temporary, "other.git")
    write_state(state)

    status = updater.status

    assert_equal true, status.dig(:plugin, :refresh_required)
    assert_equal "manual-update-required", status.dig(:plugin, :action)
    assert_includes status.dig(:plugin, :reason), "official Agent OS Git marketplace"
    assert_empty mutating_commands
  end

  def test_packaged_runtime_reads_exact_checkout_tag_when_codex_metadata_is_absent
    FileUtils.remove_entry(@marketplace_root)
    git!("clone", "--branch", "v0.1.0", @marketplace_remote, @marketplace_root)

    status = updater.status

    assert_equal "v0.1.0", status.dig(:plugin, :marketplace_ref)
    assert_equal "install-packaged-release", status.dig(:plugin, :action)
    assert_empty mutating_commands
  end

  private

  def updater(command_timeout: AgentOS::Updater::COMMAND_TIMEOUT_SECONDS)
    AgentOS::Updater.new(
      source: @runtime,
      environment: {
        "PATH" => [@bin, ENV.fetch("PATH", "/usr/bin:/bin")].join(File::PATH_SEPARATOR),
        "FAKE_CODEX_STATE" => @state_path
      },
      marketplace_source: @marketplace_remote,
      command_timeout: command_timeout
    )
  end

  def write_runtime(version:, plugin_version:)
    File.write(
      File.join(@runtime, ".agent-os-runtime.json"),
      JSON.generate(schema_version: 1, version: version, plugin_version: plugin_version, files: {})
    )
  end

  def create_release_remote
    remote = File.join(@temporary, "releases.git")
    publisher = File.join(@temporary, "publisher")
    git!("init", "--bare", remote)
    git!("init", "-b", "main", publisher)
    git!("-C", publisher, "config", "user.name", "Agent OS Test")
    git!("-C", publisher, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(publisher, "release.txt"), "releases\n")
    git!("-C", publisher, "add", "release.txt")
    git!("-C", publisher, "commit", "-m", "releases")
    git!("-C", publisher, "tag", "v0.1.0")
    git!("-C", publisher, "tag", "v0.2.0")
    git!("-C", publisher, "remote", "add", "origin", remote)
    git!("-C", publisher, "push", "origin", "main", "--tags")
    remote
  end

  def git!(*arguments)
    _stdout, stderr, status = Open3.capture3("git", *arguments)
    raise stderr unless status.success?
  end

  def write_state(state)
    File.write(@state_path, JSON.pretty_generate(state))
  end

  def read_state
    JSON.parse(File.read(@state_path))
  end

  def metadata_path
    File.join(@marketplace_root, AgentOS::Updater::MARKETPLACE_METADATA)
  end

  def write_marketplace_metadata(ref)
    File.write(metadata_path, JSON.generate(schema_version: 1, ref_name: ref, revision: "test"))
  end

  def mutating_commands
    read_state.fetch("commands").select do |arguments|
      arguments[0, 2] == %w[plugin remove] ||
        arguments[0, 2] == %w[plugin add] ||
        arguments[0, 3] == %w[plugin marketplace remove] ||
        arguments[0, 3] == %w[plugin marketplace add]
    end
  end

  def write_fake_codex
    executable = File.join(@bin, "codex")
    script = "#!#{RbConfig.ruby}\n" + <<~'RUBY'
      require "fileutils"
      require "json"

      state_path = ENV.fetch("FAKE_CODEX_STATE")
      state = JSON.parse(File.read(state_path))
      arguments = ARGV.dup
      state["commands"] << arguments

      save = lambda do
        File.write(state_path, JSON.pretty_generate(state))
      end
      write_metadata = lambda do |ref|
        root = state.fetch("marketplace_root")
        FileUtils.mkdir_p(root)
        File.write(
          File.join(root, ".codex-marketplace-install.json"),
          JSON.generate(schema_version: 1, ref_name: ref, revision: "test")
        )
      end

      if arguments[0, 3] == ["plugin", "marketplace", "list"]
        marketplace = state["marketplace"]
        payload = { marketplaces: [] }
        if marketplace
          payload[:marketplaces] << {
            name: "agent-os",
            root: state.fetch("marketplace_root"),
            marketplaceSource: {
              sourceType: marketplace.fetch("source_type"),
              source: marketplace.fetch("source")
            }
          }
        end
        save.call
        puts JSON.generate(payload)
      elsif arguments[0, 3] == ["plugin", "marketplace", "remove"]
        state["marketplace"] = nil
        save.call
        puts JSON.generate(removed: true)
      elsif arguments[0, 3] == ["plugin", "marketplace", "add"]
        ref_index = arguments.index("--ref")
        ref = ref_index && arguments[ref_index + 1]
        state["marketplace"] = {
          "source_type" => "git",
          "source" => arguments.fetch(3),
          "ref" => ref
        }
        write_metadata.call(ref)
        save.call
        puts JSON.generate(added: true)
      elsif arguments[0, 2] == ["plugin", "list"]
        installed = []
        if state["installed_version"]
          marketplace = state["marketplace"] || {}
          installed << {
            pluginId: "agent-os@agent-os",
            name: "agent-os",
            marketplaceName: "agent-os",
            version: state.fetch("installed_version"),
            installed: true,
            enabled: true,
            marketplaceSource: {
              sourceType: marketplace["source_type"],
              source: marketplace["source"]
            }
          }
        end
        save.call
        puts JSON.generate(installed: installed, available: [])
      elsif arguments[0, 2] == ["plugin", "remove"]
        state["installed_version"] = nil
        save.call
        puts JSON.generate(removed: true)
      elsif arguments[0, 2] == ["plugin", "add"]
        ref = state.fetch("marketplace").fetch("ref")
        if state["sleep_add_ref"] == ref && !state["slept_once"]
          state["slept_once"] = true
          save.call
          sleep 2
        end
        if state["fail_add_ref"] == ref && !state["failed_once"]
          state["failed_once"] = true
          save.call
          warn "simulated plugin install failure"
          exit 1
        end
        state["installed_version"] = state.fetch("versions").fetch(ref)
        save.call
        puts JSON.generate(installed: true)
      else
        save.call
        warn "unsupported fake Codex command: #{arguments.join(" ")}"
        exit 2
      end
    RUBY
    File.write(executable, script)
    File.chmod(0o755, executable)
  end
end
