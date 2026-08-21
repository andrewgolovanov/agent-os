# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

class AgentOSCLITest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-cli-")
    @home = File.join(@temporary, "home")
    @source = File.expand_path("..", __dir__)
    @executable = File.join(@source, "bin", "agent-os")
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_init_is_preview_first_and_preserves_existing_config
    stdout, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home
    )
    assert status.success?, stderr
    assert_includes stdout, "Preview only"
    refute File.exist?(@home)

    stdout, stderr, status = Open3.capture3(
      { "TZ" => "Europe/Madrid" },
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    assert_includes stdout, "Initialized Agent OS home"
    assert File.file?(File.join(@home, "work", "board.json"))
    assert_equal "#{@source}\n", File.read(File.join(@home, "source-path"))
    projects = File.read(File.join(@home, "config", "projects.yaml"))
    assert_includes projects, "agent_os:"
    refute_includes projects, "workspace:"
    assert_includes projects, "root: #{@home}"
    assert_includes projects, "timezone: Europe/Madrid"

    File.write(File.join(@home, "config", "projects.yaml"), "preserved\n")
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    assert_equal "preserved\n", File.read(File.join(@home, "config", "projects.yaml"))
  end

  def test_doctor_reports_clean_initialized_home
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr

    stdout, stderr, status = Open3.capture3(
      @executable, "doctor", "--source", @source, "--home", @home, "--json"
    )
    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal true, payload.fetch("ready")
    assert_equal @home, payload.fetch("home")
  end

  def test_bootstrap_initializes_private_home_and_active_pointer
    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }
    stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", @source, "--home", @home, "--apply", "--json"
    )

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal true, payload.fetch("applied")
    assert_equal @source, payload.fetch("source")
    assert File.file?(File.join(@home, "config", "projects.yaml"))
    assert File.file?(File.join(@home, "work", "board.json"))
    assert_equal "#{@source}\n", File.read(File.join(@home, "source-path"))
    assert_equal "#{@home}\n", File.read(File.join(@temporary, ".config", "agent-os", "home"))
  end

  def test_bootstrap_upgrades_packaged_runtime_but_preserves_development_checkout
    runtime_one = fake_runtime("0.1.0")
    runtime_two = fake_runtime("0.2.0")
    packaged_home = File.join(@temporary, "packaged-home")
    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }

    _stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", runtime_one, "--home", packaged_home, "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "#{runtime_one}\n", File.read(File.join(packaged_home, "source-path"))

    _stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", runtime_two, "--home", packaged_home, "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "#{runtime_two}\n", File.read(File.join(packaged_home, "source-path"))

    development_home = File.join(@temporary, "development-home")
    _stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", @source, "--home", development_home, "--apply", "--json"
    )
    assert status.success?, stderr
    _stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", runtime_two, "--home", development_home, "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "#{@source}\n", File.read(File.join(development_home, "source-path"))

    stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", runtime_two, "--home", development_home,
      "--replace-source", "--json"
    )
    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal false, payload.fetch("applied")
    assert_equal true, payload.fetch("replace_source")
    assert_equal runtime_two, payload.fetch("source")
    assert_equal "replace", payload.fetch("plan").find { |item| item.fetch("path").end_with?("source-path") }.fetch("action")
    assert_equal "#{@source}\n", File.read(File.join(development_home, "source-path"))

    _stdout, stderr, status = Open3.capture3(
      environment,
      @executable, "bootstrap", "--source", runtime_two, "--home", development_home,
      "--replace-source", "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "#{runtime_two}\n", File.read(File.join(development_home, "source-path"))
  end

  def test_slack_monitor_setup_is_preview_first_idempotent_and_conflict_safe
    _, stderr, status = Open3.capture3(
      { "TZ" => "Europe/Madrid" },
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    config_path = File.join(@home, "config", "monitors.yaml")
    initial = File.read(config_path)

    stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--days", "MO,TU,WE,TH,FR", "--times", "10:00,14:00,18:00"
    )
    assert status.success?, stderr
    assert_includes stdout, "Preview only"
    assert_equal initial, File.read(config_path)

    stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "create", JSON.parse(stdout).fetch("action")
    config = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: false)
    monitor = config.dig("monitors", "agent-os-slack-monitor")
    assert_equal true, monitor.fetch("enabled")
    assert_equal %w[10:00 14:00 18:00], monitor.dig("schedule", "local_times")
    assert_equal false, monitor.dig("authority", "slack_write")
    assert_equal true, monitor.dig("slack_sources", "bot_mentions", "discover_visible_channels_each_run")
    assert_equal true, monitor.dig("slack_sources", "bot_mentions", "require_exact_current_user_mention")
    assert_equal File.join(@home, "work"), monitor.fetch("task_board_root")
    assert_equal "Open Agent OS", monitor.dig("notifications", "agent_os_app", "label")
    assert_equal "agent-os://board", monitor.dig("notifications", "agent_os_app", "url")
    assert_equal 0o600, File.stat(config_path).mode & 0o777

    stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "preserve", JSON.parse(stdout).fetch("action")

    monitor.fetch("schedule")["local_times"] = ["09:00"]
    File.write(config_path, YAML.dump(config))
    before_conflict = File.read(config_path)
    stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--json"
    )
    assert status.success?, stderr
    conflict = JSON.parse(stdout)
    assert_equal "conflict", conflict.fetch("action")
    assert_equal ["09:00"], conflict.dig("existing_schedule", "local_times")
    assert_equal before_conflict, File.read(config_path)

    _stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--apply"
    )
    refute status.success?
    assert_includes stderr, "already differs"
    assert_equal before_conflict, File.read(config_path)

    stdout, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "Europe/Madrid", "--times", "11:00,15:00", "--replace", "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal "replace", JSON.parse(stdout).fetch("action")
    replaced = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: false)
    assert_equal %w[11:00 15:00], replaced.dig("monitors", "agent-os-slack-monitor", "schedule", "local_times")
  end

  def test_codex_project_sync_previews_then_registers_a_local_project
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    repository = File.join(@temporary, "codex-project")
    FileUtils.mkdir_p(repository)

    stdout, stderr, status = Open3.capture3(
      @executable, "sync-codex-projects", "--source", @source, "--home", @home,
      "--directory", repository, "--json"
    )
    assert status.success?, stderr
    assert_equal "create", JSON.parse(stdout).dig("projects", 0, "action")
    assert_equal({}, YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml"))).fetch("projects"))

    stdout, stderr, status = Open3.capture3(
      @executable, "sync-codex-projects", "--source", @source, "--home", @home,
      "--directory", repository, "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal 1, JSON.parse(stdout).fetch("registered_count")
    project = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml"))).dig("projects", "codex-project")
    assert_equal File.realpath(repository), project.fetch("root")
    assert_empty project.fetch("repositories")
  end

  def test_doctor_integration_checks_do_not_change_core_readiness
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    _, stderr, status = Open3.capture3(
      @executable, "configure-slack-monitor", "--source", @source, "--home", @home,
      "--timezone", "UTC", "--apply"
    )
    assert status.success?, stderr

    stdout, stderr, status = Open3.capture3(
      @executable, "doctor", "--source", @source, "--home", @home, "--integrations", "--json"
    )
    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal true, payload.fetch("ready")
    assert_equal true, payload.fetch("integrations_checked")
    checks = payload.fetch("checks").to_h { |check| [check.fetch("name"), check] }
    assert_equal true, checks.fetch("Slack monitor configuration").fetch("ok")
    assert_equal true, checks.fetch("Task Bridge hook bundle").fetch("ok")
    assert_equal false, checks.fetch("connected Slack integration").fetch("required")
    assert_equal false, checks.fetch("Scheduled task").fetch("ok")
  end

  def test_doctor_finds_hooks_next_to_a_packaged_runtime
    plugin_root = File.join(@temporary, "packaged-plugin")
    runtime = File.join(plugin_root, "runtime")
    FileUtils.mkdir_p(plugin_root)
    FileUtils.cp_r(fake_runtime("0.3.0"), runtime)
    hooks = File.join(plugin_root, "hooks")
    FileUtils.mkdir_p(hooks)
    File.write(File.join(hooks, "hooks.json"), "{}\n")
    runner = File.join(hooks, "agent-os-task-bridge")
    File.write(runner, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, runner)

    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", runtime, "--home", @home, "--apply"
    )
    assert status.success?, stderr
    stdout, stderr, status = Open3.capture3(
      @executable, "doctor", "--source", runtime, "--home", @home,
      "--integrations", "--json"
    )
    assert status.success?, stderr
    checks = JSON.parse(stdout).fetch("checks").to_h { |check| [check.fetch("name"), check] }
    hook_check = checks.fetch("Task Bridge hook bundle")
    assert_equal true, hook_check.fetch("ok")
    assert_includes hook_check.fetch("detail"), File.join(plugin_root, "hooks", "hooks.json")
  end

  def test_activate_is_preview_first_and_writes_user_pointer
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr

    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }
    stdout, stderr, status = Open3.capture3(
      environment, @executable, "activate", "--home", @home
    )
    assert status.success?, stderr
    assert_includes stdout, "Preview only"
    pointer = File.join(@temporary, ".config", "agent-os", "home")
    refute File.exist?(pointer)

    _, stderr, status = Open3.capture3(
      environment, @executable, "activate", "--home", @home, "--apply"
    )
    assert status.success?, stderr
    assert_equal "#{@home}\n", File.read(pointer)
  end

  def test_doctor_uses_activated_home_without_an_environment_override
    _, stderr, status = Open3.capture3(
      @executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    assert status.success?, stderr

    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }
    _, stderr, status = Open3.capture3(
      environment, @executable, "activate", "--home", @home, "--apply"
    )
    assert status.success?, stderr

    stdout, stderr, status = Open3.capture3(
      environment, @executable, "doctor", "--source", @source, "--json"
    )
    assert status.success?, stderr
    assert_equal @home, JSON.parse(stdout).fetch("home")
  end

  def test_activate_requires_explicit_replace_for_a_different_home
    first = File.join(@temporary, "first-home")
    second = File.join(@temporary, "second-home")
    [first, second].each do |home|
      _, stderr, status = Open3.capture3(@executable, "init", "--source", @source, "--home", home, "--apply")
      assert status.success?, stderr
    end
    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }
    _, stderr, status = Open3.capture3(environment, @executable, "activate", "--home", first, "--apply")
    assert status.success?, stderr

    _, stderr, status = Open3.capture3(environment, @executable, "activate", "--home", second, "--apply")
    refute status.success?
    assert_includes stderr, "was not overwritten"

    stdout, stderr, status = Open3.capture3(environment, @executable, "activate", "--home", second, "--replace")
    assert status.success?, stderr
    assert_includes stdout, "REPLACE"
    assert_equal "#{first}\n", File.read(File.join(@temporary, ".config", "agent-os", "home"))

    _, stderr, status = Open3.capture3(environment, @executable, "activate", "--home", second, "--replace", "--apply")
    assert status.success?, stderr
    assert_equal "#{second}\n", File.read(File.join(@temporary, ".config", "agent-os", "home"))
  end

  def test_migrate_home_copies_private_state_and_archives_legacy_project_folder
    legacy = File.join(@temporary, "legacy-home")
    migrated = File.join(@temporary, "migrated-home")
    environment = { "HOME" => @temporary, "AGENT_OS_HOME" => nil }
    _, stderr, status = Open3.capture3(
      environment, @executable, "init", "--source", @source, "--home", legacy, "--apply"
    )
    assert status.success?, stderr

    repository = File.join(@temporary, "external-repository")
    FileUtils.mkdir_p(repository)
    wrapper = File.join(legacy, "projects", "example")
    FileUtils.mkdir_p(wrapper)
    File.write(File.join(wrapper, "README.md"), "private wrapper\n")
    registry_path = File.join(legacy, "config", "projects.yaml")
    registry = YAML.safe_load(File.read(registry_path), aliases: false)
    registry.fetch("projects")["example"] = {
      "display_name" => "Example",
      "status" => "active",
      "layout" => "wrapper",
      "aliases" => [],
      "wrapper" => wrapper,
      "repositories" => [{ "id" => "repo", "path" => repository }]
    }
    File.write(registry_path, YAML.dump(registry))
    monitors_path = File.join(legacy, "config", "monitors.yaml")
    File.write(
      monitors_path,
      YAML.dump(
        "schema_version" => 1,
        "monitors" => {
          "agent-os-slack-monitor" => {
            "runbook" => File.join(legacy, "docs", "slack-monitor.md"),
            "source_registry" => File.join(legacy, "config", "projects.yaml"),
            "task_board_root" => File.join(legacy, "work"),
            "runtime_state_root" => File.join(legacy, ".runtime", "dispatcher"),
            "notifications" => {
              "task_board_dashboard" => { "path" => File.join(legacy, "work", "BOARD.md") }
            }
          },
          "unrelated-monitor" => {
            "runbook" => "/opt/example/custom-monitor.md",
            "source_registry" => "/opt/example/custom-projects.yaml"
          }
        }
      )
    )
    FileUtils.mkdir_p(File.join(legacy, ".runtime", "task-bridge"))
    File.write(File.join(legacy, ".runtime", "task-bridge", "marker"), "preserved\n")
    _, stderr, status = Open3.capture3(
      environment, @executable, "activate", "--home", legacy, "--apply"
    )
    assert status.success?, stderr

    stdout, stderr, status = Open3.capture3(
      environment, @executable, "migrate-home", "--from", legacy, "--home", migrated,
      "--source", @source, "--json"
    )
    assert status.success?, stderr
    assert_equal false, JSON.parse(stdout).fetch("applied")
    refute File.exist?(migrated)

    stdout, stderr, status = Open3.capture3(
      environment, @executable, "migrate-home", "--from", legacy, "--home", migrated,
      "--source", @source, "--apply", "--json"
    )
    assert status.success?, stderr
    assert_equal true, JSON.parse(stdout).fetch("applied")
    assert_equal "preserved\n", File.read(File.join(migrated, ".runtime", "task-bridge", "marker"))
    legacy_backup = File.join(migrated, ".runtime", "legacy-project-backups", "example")
    assert_equal "private wrapper\n", File.read(File.join(legacy_backup, "README.md"))
    migrated_registry = YAML.safe_load(File.read(File.join(migrated, "config", "projects.yaml")), aliases: false)
    assert_equal migrated, migrated_registry.dig("agent_os", "root")
    assert_equal repository, migrated_registry.dig("projects", "example", "root")
    refute migrated_registry.dig("projects", "example").key?("layout")
    refute migrated_registry.dig("projects", "example").key?("wrapper")
    assert_equal repository, migrated_registry.dig("projects", "example", "repositories", 0, "path")
    refute File.exist?(File.join(migrated, "projects"))
    migrated_monitors = YAML.safe_load(File.read(File.join(migrated, "config", "monitors.yaml")), aliases: false)
    migrated_monitor = migrated_monitors.dig("monitors", "agent-os-slack-monitor")
    assert_equal File.join(@source, "docs", "slack-monitor.md"), migrated_monitor.fetch("runbook")
    assert_equal File.join(migrated, "config", "projects.yaml"), migrated_monitor.fetch("source_registry")
    assert_equal File.join(migrated, "work"), migrated_monitor.fetch("task_board_root")
    assert_equal File.join(migrated, ".runtime", "dispatcher"), migrated_monitor.fetch("runtime_state_root")
    assert_nil migrated_monitor.dig("notifications", "task_board_dashboard")
    assert_equal "Open Agent OS", migrated_monitor.dig("notifications", "agent_os_app", "label")
    assert_equal "agent-os://board", migrated_monitor.dig("notifications", "agent_os_app", "url")
    assert_equal(
      {
        "runbook" => "/opt/example/custom-monitor.md",
        "source_registry" => "/opt/example/custom-projects.yaml"
      },
      migrated_monitors.dig("monitors", "unrelated-monitor")
    )
    assert_equal "#{migrated}\n", File.read(File.join(@temporary, ".config", "agent-os", "home"))
    assert File.directory?(legacy)
    assert File.directory?(repository)
  end

  def test_update_is_preview_first_and_fast_forwards_only_to_release_tag
    remote = File.join(@temporary, "remote.git")
    publisher = File.join(@temporary, "publisher")
    checkout = File.join(@temporary, "checkout")
    system("git", "init", "--bare", remote, out: File::NULL, err: File::NULL) or flunk "bare repo init failed"
    system("git", "init", "-b", "main", publisher, out: File::NULL, err: File::NULL) or flunk "publisher init failed"
    git(publisher, "config", "user.name", "Agent OS Test")
    git(publisher, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(publisher, "release.txt"), "0.1.0\n")
    git(publisher, "add", "release.txt")
    git(publisher, "commit", "-m", "release 0.1.0")
    git(publisher, "tag", "v0.1.0")
    git(publisher, "remote", "add", "origin", remote)
    git(publisher, "push", "-u", "origin", "main", "--tags")
    system("git", "clone", remote, checkout, out: File::NULL, err: File::NULL) or flunk "clone failed"
    git(checkout, "checkout", "main")

    File.write(File.join(publisher, "release.txt"), "0.2.0\n")
    git(publisher, "add", "release.txt")
    git(publisher, "commit", "-m", "release 0.2.0")
    git(publisher, "tag", "v0.2.0")
    git(publisher, "push", "origin", "main", "--tags")

    stdout, stderr, status = Open3.capture3(
      @executable, "update", "--source", checkout, "--no-plugin", "--json"
    )
    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal true, payload.fetch("update_available")
    assert_equal "0.1.0", payload.dig("source", "current_version")
    assert_equal "0.2.0", payload.dig("source", "latest_version")
    assert_equal "0.1.0\n", File.read(File.join(checkout, "release.txt"))

    stdout, stderr, status = Open3.capture3(
      @executable, "update", "--source", checkout, "--no-plugin", "--apply", "--json"
    )
    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal true, payload.fetch("updated")
    assert_equal "0.2.0", payload.dig("source", "current_version")
    assert_equal "0.2.0\n", File.read(File.join(checkout, "release.txt"))
  end

  def test_update_refuses_a_dirty_checkout
    remote = File.join(@temporary, "dirty-remote.git")
    publisher = File.join(@temporary, "dirty-publisher")
    checkout = File.join(@temporary, "dirty-checkout")
    system("git", "init", "--bare", remote, out: File::NULL, err: File::NULL) or flunk "bare repo init failed"
    system("git", "init", "-b", "main", publisher, out: File::NULL, err: File::NULL) or flunk "publisher init failed"
    git(publisher, "config", "user.name", "Agent OS Test")
    git(publisher, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(publisher, "release.txt"), "0.1.0\n")
    git(publisher, "add", "release.txt")
    git(publisher, "commit", "-m", "release 0.1.0")
    git(publisher, "tag", "v0.1.0")
    git(publisher, "remote", "add", "origin", remote)
    git(publisher, "push", "-u", "origin", "main", "--tags")
    system("git", "clone", remote, checkout, out: File::NULL, err: File::NULL) or flunk "clone failed"
    git(checkout, "checkout", "main")
    File.write(File.join(publisher, "release.txt"), "0.2.0\n")
    git(publisher, "add", "release.txt")
    git(publisher, "commit", "-m", "release 0.2.0")
    git(publisher, "tag", "v0.2.0")
    git(publisher, "push", "origin", "main", "--tags")
    File.write(File.join(checkout, "local.txt"), "keep me\n")

    _stdout, stderr, status = Open3.capture3(
      @executable, "update", "--source", checkout, "--no-plugin", "--apply"
    )
    refute status.success?
    assert_includes stderr, "local changes"
    assert_equal "0.1.0\n", File.read(File.join(checkout, "release.txt"))
    assert_equal "keep me\n", File.read(File.join(checkout, "local.txt"))
  end

  def test_update_rejects_a_git_option_as_the_remote_name
    _stdout, stderr, status = Open3.capture3(
      @executable, "update", "--source", @source, "--remote", "--upload-pack=malicious", "--no-plugin"
    )

    refute status.success?
    assert_includes stderr, "invalid Git remote name"
  end

  def test_update_recognizes_a_packaged_runtime_as_app_managed
    runtime = fake_runtime("0.2.0")

    stdout, stderr, status = Open3.capture3(
      @executable, "update", "--source", runtime, "--no-plugin", "--json"
    )

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal false, payload.fetch("update_available")
    assert_equal true, payload.dig("source", "configured")
    assert_equal "0.2.0", payload.dig("source", "current_version")
    assert_equal "managed-by-app", payload.dig("source", "action")
  end

  private

  def fake_runtime(version)
    root = File.join(@temporary, "runtime-#{version}")
    FileUtils.mkdir_p(File.join(root, "config", "examples"))
    FileUtils.mkdir_p(File.join(root, "tools"))
    %w[projects.yaml monitors.yaml task-bridge.yaml].each do |name|
      FileUtils.cp(File.join(@source, "config", "examples", name), File.join(root, "config", "examples", name))
    end
    File.write(File.join(root, "tools", "task-board"), "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, File.join(root, "tools", "task-board"))
    File.write(
      File.join(root, ".agent-os-runtime.json"),
      JSON.generate({ schema_version: 1, version: version, plugin_version: version, files: {} })
    )
    root
  end

  def git(directory, *arguments)
    _stdout, stderr, status = Open3.capture3("git", *arguments, chdir: directory)
    assert status.success?, stderr
  end
end
