# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"
require_relative "../lib/agent_os/codex_project_sync"

class CodexProjectSyncTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-codex-project-sync-")
    @source = File.expand_path("..", __dir__)
    @home = File.join(@temporary, "home")
    run_command(File.join(@source, "bin", "agent-os"), "init", "--source", @source, "--home", @home, "--apply")
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_sync_registers_a_local_project_without_git_and_collapses_nested_paths
    project = create_directory("local-project")
    nested = File.join(project, "docs")
    FileUtils.mkdir_p(nested)

    result = synchronizer.sync(
      directories: [project, nested, File.join(@temporary, "missing")],
      apply: true
    )

    assert_equal 3, result.fetch(:discovered_count)
    assert_equal 1, result.fetch(:eligible_count)
    assert_equal 1, result.fetch(:registered_count)
    assert_equal 2, result.fetch(:skipped_count)
    assert_equal "local-project", result.dig(:projects, 0, :project_key)
    registered = registry.dig("projects", "local-project")
    assert_equal File.realpath(project), registered.fetch("root")
    assert_empty registered.fetch("repositories")

    repeated = synchronizer.sync(directories: [nested], apply: true)
    assert_equal 0, repeated.fetch(:registered_count)
    assert_equal 1, repeated.fetch(:preserved_count)
    assert_equal "preserve", repeated.dig(:projects, 0, :action)
  end

  def test_sync_enriches_the_same_local_project_when_git_and_a_remote_appear_later
    project = create_directory("future-project")
    synchronizer.sync(directories: [project], apply: true)

    initialize_repository(project)
    enriched = synchronizer.sync(directories: [project], apply: true)

    assert_equal 1, enriched.fetch(:enriched_count)
    assert_equal "enriched", enriched.dig(:projects, 0, :action)
    registered = registry.dig("projects", "future-project")
    assert_equal File.realpath(project), registered.fetch("root")
    assert_equal 1, registered.fetch("repositories").length
    refute registered.fetch("repositories").first.key?("remotes")

    run_command("git", "-C", project, "remote", "add", "origin", "https://example.invalid/future-project.git")
    refreshed = synchronizer.sync(directories: [project], apply: true)

    assert_equal 1, refreshed.fetch(:refreshed_count)
    assert_equal "refreshed", refreshed.dig(:projects, 0, :action)
    assert_equal(
      "https://example.invalid/future-project.git",
      registry.dig("projects", "future-project", "repositories", 0, "remotes", "origin")
    )
    assert_equal ["future-project"], registry.fetch("projects").keys
  end

  def test_unborn_git_repository_remains_a_valid_local_only_project
    project = create_directory("unborn-project")
    run_command("git", "-C", project, "init", "-q")

    result = synchronizer.sync(directories: [project], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_empty registry.dig("projects", "unborn-project", "repositories")
  end

  def test_sync_uses_a_stable_suffix_when_two_local_projects_share_a_name
    first = create_directory(File.join("one", "shared"))
    second = create_directory(File.join("two", "shared"))

    result = synchronizer.sync(directories: [first, second], apply: true)

    assert_equal 2, result.fetch(:registered_count)
    keys = registry.fetch("projects").keys
    assert_includes keys, "shared"
    other_key = keys.find { |key| key != "shared" }
    other_root = registry.dig("projects", other_key, "root")
    expected = "shared-#{Digest::SHA256.hexdigest(other_root)[0, 8]}"
    assert_includes keys, expected
  end

  def test_sync_deduplicates_clones_by_normalized_origin
    first = create_repository("first", "git@github.com:example/shared.git")
    second = create_repository("second", "https://github.com/example/shared")

    result = synchronizer.sync(directories: [first, second], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_equal 1, result.fetch(:skipped_count)
    assert_equal "duplicate", result.dig(:skipped, 0, :action)
  end

  def test_sync_does_not_register_a_second_path_for_an_existing_origin
    first = create_repository("registered-copy", "git@github.com:example/shared.git")
    second = create_repository("other-copy", "https://github.com/example/shared")
    synchronizer.sync(directories: [first], apply: true)

    result = synchronizer.sync(directories: [second], apply: true)

    assert_equal 0, result.fetch(:registered_count)
    assert_equal 1, result.fetch(:skipped_count)
    assert_match(/already registered/, result.dig(:skipped, 0, :reason))
    assert_equal ["registered-copy"], registry.fetch("projects").keys
  end

  def test_sync_normalizes_a_codex_worktree_to_the_durable_checkout
    repository = create_repository("durable-project", "https://example.invalid/durable-project.git")
    worktree = File.join(@temporary, ".codex", "worktrees", "thread-1", "durable-project")
    FileUtils.mkdir_p(File.dirname(worktree))
    run_command("git", "-C", repository, "worktree", "add", "--detach", worktree, "HEAD")

    result = synchronizer.sync(directories: [worktree], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_equal File.realpath(repository), result.dig(:projects, 0, :repository)
    assert_equal File.realpath(repository), registry.dig("projects", "durable-project", "root")
  end

  def test_sync_refuses_a_parent_that_would_overlap_an_existing_project
    parent = create_directory("parent")
    project = File.join(parent, "child")
    FileUtils.mkdir_p(project)
    synchronizer.sync(directories: [project], apply: true)

    result = synchronizer.sync(directories: [parent], apply: true)

    assert_equal 0, result.fetch(:registered_count)
    assert_equal 1, result.fetch(:skipped_count)
    assert_match(/contains registered project/, result.dig(:skipped, 0, :reason))
  end

  def test_sync_does_not_register_the_private_agent_os_home
    result = synchronizer.sync(directories: [@home], apply: true)

    assert_equal 0, result.fetch(:registered_count)
    assert_equal 1, result.fetch(:skipped_count)
    assert_match(/operational state/, result.dig(:skipped, 0, :reason))
    assert_equal({}, registry.fetch("projects"))
  end

  def test_preview_does_not_mutate_the_registry
    project = create_directory("preview-project")

    result = synchronizer.sync(directories: [project])

    assert_equal false, result.fetch(:applied)
    assert_equal "create", result.dig(:projects, 0, :action)
    assert_equal({}, registry.fetch("projects"))
  end

  def test_legacy_repositories_argument_remains_compatible
    project = create_directory("legacy-argument")

    result = synchronizer.sync(repositories: [project], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_empty registry.dig("projects", "legacy-argument", "repositories")
  end

  def test_agent_os_validator_accepts_a_local_only_project
    project = create_directory("validated-local-project")
    synchronizer.sync(directories: [project], apply: true)
    environment = {
      "AGENT_OS_SOURCE_ROOT" => @source,
      "AGENT_OS_HOME" => @home,
      "AGENT_OS_TASK_ROOT" => File.join(@home, "work")
    }

    _stdout, stderr, status = Open3.capture3(
      environment,
      RbConfig.ruby,
      File.join(@source, "tools", "validate-agent-os")
    )

    assert status.success?, stderr
  end

  def test_user_prompt_hook_registers_current_local_project_before_routing
    project = create_directory("future-project")
    payload = {
      "hook_event_name" => "UserPromptSubmit",
      "session_id" => "session-future",
      "turn_id" => "turn-future",
      "cwd" => project,
      "prompt" => "Start future project work"
    }
    environment = {
      "AGENT_OS_SOURCE_ROOT" => @source,
      "AGENT_OS_HOME" => @home,
      "AGENT_OS_TASK_ROOT" => File.join(@home, "work")
    }

    _stdout, stderr, status = Open3.capture3(
      environment,
      File.join(@source, "tools", "codex-activity-hook"),
      stdin_data: JSON.generate(payload)
    )

    assert status.success?, stderr
    assert_equal File.realpath(project), registry.dig("projects", "future-project", "root")
    assert_empty registry.dig("projects", "future-project", "repositories")
  end

  private

  def synchronizer
    AgentOS::CodexProjectSync.new(source: @source, home: @home)
  end

  def registry
    YAML.safe_load(
      File.read(File.join(@home, "config", "projects.yaml")),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false
    )
  end

  def create_directory(name)
    path = File.join(@temporary, name)
    FileUtils.mkdir_p(path)
    path
  end

  def create_repository(name, remote)
    path = create_directory(name)
    initialize_repository(path, remote)
    path
  end

  def initialize_repository(path, remote = nil)
    run_command("git", "-C", path, "init", "-q")
    run_command("git", "-C", path, "config", "user.email", "agent-os@example.invalid")
    run_command("git", "-C", path, "config", "user.name", "Agent OS")
    File.write(File.join(path, "README.md"), "# #{File.basename(path)}\n")
    run_command("git", "-C", path, "add", "README.md")
    run_command("git", "-C", path, "commit", "-qm", "Initial commit")
    run_command("git", "-C", path, "remote", "add", "origin", remote) if remote
  end

  def run_command(*command)
    _stdout, stderr, status = Open3.capture3(*command)
    raise stderr unless status.success?
  end
end
