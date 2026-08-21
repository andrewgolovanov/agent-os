# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
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

  def test_sync_registers_only_unique_eligible_git_roots
    repository = create_repository("sample-project", "https://example.invalid/sample-project.git")
    nested = File.join(repository, "docs")
    FileUtils.mkdir_p(nested)
    non_git = File.join(@temporary, "notes")
    FileUtils.mkdir_p(non_git)

    result = synchronizer.sync(
      repositories: [repository, nested, non_git, File.join(@temporary, "missing")],
      apply: true
    )

    assert_equal 4, result.fetch(:discovered_count)
    assert_equal 1, result.fetch(:eligible_count)
    assert_equal 1, result.fetch(:registered_count)
    assert_equal 3, result.fetch(:skipped_count)
    assert_equal "sample-project", result.dig(:projects, 0, :project_key)
    assert_equal File.realpath(repository), registry.dig("projects", "sample-project", "root")

    repeated = synchronizer.sync(repositories: [nested], apply: true)
    assert_equal 0, repeated.fetch(:registered_count)
    assert_equal 1, repeated.fetch(:preserved_count)
    assert_equal "preserve", repeated.dig(:projects, 0, :action)
  end

  def test_sync_deduplicates_clones_by_normalized_origin
    first = create_repository("first", "git@github.com:example/shared.git")
    second = create_repository("second", "https://github.com/example/shared")

    result = synchronizer.sync(repositories: [first, second], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_equal 1, result.fetch(:skipped_count)
    assert_equal "duplicate", result.dig(:skipped, 0, :action)
  end

  def test_sync_does_not_register_a_second_path_for_an_existing_origin
    first = create_repository("registered-copy", "git@github.com:example/shared.git")
    second = create_repository("other-copy", "https://github.com/example/shared")
    synchronizer.sync(repositories: [first], apply: true)

    result = synchronizer.sync(repositories: [second], apply: true)

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

    result = synchronizer.sync(repositories: [worktree], apply: true)

    assert_equal 1, result.fetch(:registered_count)
    assert_equal File.realpath(repository), result.dig(:projects, 0, :repository)
    assert_equal File.realpath(repository), registry.dig("projects", "durable-project", "root")
  end

  def test_preview_does_not_mutate_the_registry
    repository = create_repository("preview-project", nil)

    result = synchronizer.sync(repositories: [repository])

    assert_equal false, result.fetch(:applied)
    assert_equal "create", result.dig(:projects, 0, :action)
    assert_equal({}, registry.fetch("projects"))
  end

  def test_user_prompt_hook_registers_current_repository_before_routing
    repository = create_repository("future-project", "https://example.invalid/future-project.git")
    payload = {
      "hook_event_name" => "UserPromptSubmit",
      "session_id" => "session-future",
      "turn_id" => "turn-future",
      "cwd" => repository,
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
    assert_equal File.realpath(repository), registry.dig("projects", "future-project", "root")
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

  def create_repository(name, remote)
    path = File.join(@temporary, name)
    FileUtils.mkdir_p(path)
    run_command("git", "-C", path, "init", "-q")
    run_command("git", "-C", path, "config", "user.email", "agent-os@example.invalid")
    run_command("git", "-C", path, "config", "user.name", "Agent OS")
    File.write(File.join(path, "README.md"), "# #{name}\n")
    run_command("git", "-C", path, "add", "README.md")
    run_command("git", "-C", path, "commit", "-qm", "Initial commit")
    run_command("git", "-C", path, "remote", "add", "origin", remote) if remote
    path
  end

  def run_command(*command)
    _stdout, stderr, status = Open3.capture3(*command)
    raise stderr unless status.success?
  end
end
