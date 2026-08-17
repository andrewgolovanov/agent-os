# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"
require_relative "../lib/agent_os/project_registry"

class ProjectRegistryTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir("agent-os-project-registry-")
    @source = File.expand_path("..", __dir__)
    @home = File.join(@temporary, "home")
    @repository = create_repository("sample-project", "https://example.invalid/sample-project.git")
    executable = File.join(@source, "bin", "agent-os")
    _stdout, stderr, status = Open3.capture3(
      executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    raise stderr unless status.success?
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_onboarding_is_preview_first_and_registry_only
    registry = project_registry
    before_head = git_output("-C", @repository, "rev-parse", "HEAD")
    before_status = git_output("-C", @repository, "status", "--porcelain")

    preview = registry.onboard(repository: @repository, display_name: "Sample Project")

    assert_equal "create", preview.fetch(:action)
    assert_equal false, preview.fetch(:applied)
    assert_equal "sample-project", preview.dig(:project, :key)
    assert_equal File.realpath(@repository), preview.dig(:project, :root)
    assert_equal [File.join(@home, "config", "projects.yaml")], preview.fetch(:files)
    refute File.exist?(File.join(@home, "projects"))
    assert_equal({}, registry_payload.fetch("projects"))

    created = registry.onboard(repository: @repository, display_name: "Sample Project", apply: true)

    assert_equal "created", created.fetch(:action)
    assert_equal true, created.fetch(:applied)
    project = registry_payload.dig("projects", "sample-project")
    assert_equal File.realpath(@repository), project.fetch("root")
    assert_equal File.realpath(@repository), project.fetch("repositories").first.fetch("path")
    refute project.key?("layout")
    refute project.key?("wrapper")
    refute File.exist?(File.join(@home, "projects"))
    assert_equal before_head, git_output("-C", @repository, "rev-parse", "HEAD")
    assert_equal before_status, git_output("-C", @repository, "status", "--porcelain")

    nested_directory = File.join(@repository, "docs")
    FileUtils.mkdir_p(nested_directory)
    repeated = registry.onboard(repository: nested_directory, apply: true)
    assert_equal "preserve", repeated.fetch(:action)
    assert_equal false, repeated.fetch(:applied)
  end

  def test_onboarding_refuses_a_key_owned_by_another_repository
    project_registry.onboard(repository: @repository, key: "shared-key", apply: true)
    another = create_repository("another", nil)

    error = assert_raises(ArgumentError) do
      project_registry.onboard(repository: another, key: "shared-key", apply: true)
    end
    assert_includes error.message, "already belongs to another repository"
  end

  def test_onboarding_previews_and_applies_selected_slack_channel_reconciliation
    repository = create_repository("example-product-next", "https://example.invalid/example-product-next.git")
    board = AgentOS::TaskBoard.new(File.join(@home, "work"))
    board.create(
      "id" => "task_example_product",
      "title" => "Cover example product handoff",
      "goal" => "Keep the client work visible",
      "summary" => "Waiting for ownership.",
      "next_action" => "Confirm ownership."
    )
    board.upsert_label(
      "task_example_product",
      key: "slack:CEXAMPLE",
      name: "#project-example-product-int",
      kind: "slack_channel"
    )

    preview = project_registry.onboard(repository: repository)
    suggestion = preview.dig(:reconciliation, :suggested_channels, 0)

    assert_equal "create", preview.fetch(:action)
    assert_equal "CEXAMPLE", suggestion.fetch(:id)
    assert_equal ["task_example_product"], suggestion.fetch(:assign_task_ids)
    assert_empty preview.dig(:reconciliation, :selected_channels)
    assert_equal({}, registry_payload.fetch("projects"))
    assert_empty board.read_task("task_example_product").fetch("projects")

    selected_preview = project_registry.onboard(
      repository: repository,
      slack_channel_ids: ["CEXAMPLE"]
    )
    assert_equal ["CEXAMPLE"], selected_preview.dig(:reconciliation, :selected_channels).map { |channel| channel.fetch(:id) }
    assert_equal ["task_example_product"], selected_preview.dig(:reconciliation, :task_assignments).map { |item| item.fetch(:task_id) }
    assert_equal({}, registry_payload.fetch("projects"))

    applied = project_registry.onboard(
      repository: repository,
      slack_channel_ids: ["CEXAMPLE"],
      apply: true
    )

    assert_equal "created", applied.fetch(:action)
    assert_equal true, applied.fetch(:applied)
    assert_equal(
      [{ "id" => "CEXAMPLE", "name" => "#project-example-product-int" }],
      registry_payload.dig("projects", "example-product-next", "slack_channels")
    )
    task = board.read_task("task_example_product")
    assert_equal ["example-product-next"], task.fetch("projects")
    assert_equal "#project-example-product-int", task.dig("labels", 0, "name")

    repeated = project_registry.onboard(
      repository: repository,
      slack_channel_ids: ["CEXAMPLE"],
      apply: true
    )
    assert_equal "preserve", repeated.fetch(:action)
    assert_equal false, repeated.fetch(:applied)
  end

  def test_existing_project_can_reconcile_its_channel_without_rewriting_attributed_tasks
    project_registry.onboard(repository: @repository, apply: true)
    board = AgentOS::TaskBoard.new(File.join(@home, "work"))
    board.create(
      "id" => "task_sample_project",
      "title" => "Review Sample Project",
      "projects" => ["sample-project"],
      "goal" => "Keep project and channel context",
      "summary" => "Active.",
      "next_action" => "Review the thread."
    )
    board.upsert_label(
      "task_sample_project",
      key: "slack:C0SAMPLE",
      name: "#project-sample-project-int",
      kind: "slack_channel"
    )

    preview = project_registry.onboard(
      repository: @repository,
      slack_channel_ids: ["C0SAMPLE"]
    )
    assert_equal "reconcile", preview.fetch(:action)
    assert_empty preview.dig(:reconciliation, :task_assignments)

    applied = project_registry.onboard(
      repository: @repository,
      slack_channel_ids: ["C0SAMPLE"],
      apply: true
    )
    assert_equal "reconciled", applied.fetch(:action)
    assert_equal ["sample-project"], board.read_task("task_sample_project").fetch("projects")
    assert_equal "C0SAMPLE", registry_payload.dig("projects", "sample-project", "slack_channels", 0, "id")
  end

  def test_onboarding_does_not_suggest_a_channel_owned_by_another_project_task
    repository = create_repository("example-product-next", "https://example.invalid/example-product-next.git")
    board = AgentOS::TaskBoard.new(File.join(@home, "work"))
    board.create(
      "id" => "task_conflict",
      "title" => "Work in another repository",
      "projects" => ["devhub"],
      "goal" => "Preserve verified attribution",
      "summary" => "Already attributed.",
      "next_action" => "Keep the current owner."
    )
    board.upsert_label(
      "task_conflict",
      key: "slack:CEXAMPLE",
      name: "#project-example-product-int",
      kind: "slack_channel"
    )

    preview = project_registry.onboard(repository: repository)

    assert_empty preview.dig(:reconciliation, :suggested_channels)
    error = assert_raises(ArgumentError) do
      project_registry.onboard(repository: repository, slack_channel_ids: ["CEXAMPLE"], apply: true)
    end
    assert_includes error.message, "not safe onboarding suggestions"
    assert_equal({}, registry_payload.fetch("projects"))
    assert_equal ["devhub"], board.read_task("task_conflict").fetch("projects")
  end

  def test_onboarding_never_reconciles_finished_slack_outcomes
    repository = create_repository("example-product-next", "https://example.invalid/example-product-next.git")
    board = AgentOS::TaskBoard.new(File.join(@home, "work"))
    board.create(
      "id" => "task_finished_example_product",
      "title" => "Complete example product handoff",
      "status" => "done",
      "goal" => "Retain completed history",
      "summary" => "Complete.",
      "next_action" => "None."
    )
    board.upsert_label(
      "task_finished_example_product",
      key: "slack:CEXAMPLE",
      name: "#project-example-product-int",
      kind: "slack_channel"
    )

    preview = project_registry.onboard(repository: repository)

    assert_empty preview.dig(:reconciliation, :suggested_channels)
    assert_empty board.read_task("task_finished_example_product").fetch("projects")
  end

  def test_onboarding_requires_obsolete_registry_metadata_to_be_upgraded
    write_legacy_project(layout: "direct-repository", wrapper: @repository)

    error = assert_raises(ArgumentError) do
      project_registry.onboard(repository: @repository, apply: true)
    end

    assert_includes error.message, "upgrade-project-registry"
    assert registry_payload.dig("projects", "sample-project").key?("layout")
    assert registry_payload.dig("projects", "sample-project").key?("wrapper")
  end

  def test_relink_is_preview_first_and_updates_root_and_repository_path
    registry = project_registry
    registry.onboard(repository: @repository, display_name: "Sample Project", apply: true)
    previous_path = File.realpath(@repository)
    before_head = git_output("-C", @repository, "rev-parse", "HEAD")
    moved_repository = File.join(@temporary, "moved-project")
    FileUtils.mv(@repository, moved_repository)

    preview = registry.relink(repository: moved_repository, key: "sample-project")

    assert_equal "replace", preview.fetch(:action)
    assert_equal false, preview.fetch(:applied)
    assert_equal previous_path, preview.fetch(:previous_path)
    assert_equal File.realpath(moved_repository), preview.dig(:repository, :path)
    assert_equal previous_path, registry_payload.dig("projects", "sample-project", "root")

    applied = registry.relink(repository: moved_repository, key: "sample-project", apply: true)

    assert_equal "relinked", applied.fetch(:action)
    assert_equal true, applied.fetch(:applied)
    project = registry_payload.dig("projects", "sample-project")
    assert_equal File.realpath(moved_repository), project.fetch("root")
    assert_equal File.realpath(moved_repository), project.fetch("repositories").first.fetch("path")
    refute File.exist?(File.join(@home, "projects"))
    assert_equal before_head, git_output("-C", moved_repository, "rev-parse", "HEAD")
    assert_equal "", git_output("-C", moved_repository, "status", "--porcelain")
  end

  def test_registry_upgrade_is_preview_first_and_preserves_legacy_folder_in_recovery
    legacy_path = File.join(@home, "projects", "sample-project")
    FileUtils.mkdir_p(legacy_path)
    File.write(File.join(legacy_path, "README.md"), "keep this private context\n")
    write_legacy_project(layout: "wrapper", wrapper: legacy_path)
    backup = File.join(@home, ".runtime", "legacy-project-backups", "sample-project")

    preview = project_registry.upgrade_registry

    assert_equal "upgrade", preview.fetch(:action)
    assert_equal false, preview.fetch(:applied)
    assert_equal backup, preview.dig(:projects, 0, :backup)
    assert File.directory?(legacy_path)
    refute File.exist?(backup)
    assert registry_payload.dig("projects", "sample-project").key?("wrapper")

    applied = project_registry.upgrade_registry(apply: true)

    assert_equal "upgraded", applied.fetch(:action)
    assert_equal true, applied.fetch(:applied)
    refute File.exist?(legacy_path)
    assert_equal "keep this private context\n", File.read(File.join(backup, "README.md"))
    project = registry_payload.dig("projects", "sample-project")
    assert_equal File.realpath(@repository), project.fetch("root")
    refute project.key?("layout")
    refute project.key?("wrapper")

    repeated = project_registry.upgrade_registry(apply: true)
    assert_equal "preserve", repeated.fetch(:action)
    assert_equal false, repeated.fetch(:applied)
  end

  def test_registry_upgrade_removes_legacy_direct_metadata_without_creating_files
    write_legacy_project(layout: "direct-repository", wrapper: @repository)

    applied = project_registry.upgrade_registry(apply: true)

    assert_equal "upgraded", applied.fetch(:action)
    assert_nil applied.dig(:projects, 0, :backup)
    project = registry_payload.dig("projects", "sample-project")
    assert_equal File.realpath(@repository), project.fetch("root")
    refute project.key?("layout")
    refute project.key?("wrapper")
    refute File.exist?(File.join(@home, "projects"))
  end

  def test_registry_upgrade_refuses_to_overwrite_an_existing_recovery_backup
    legacy_path = File.join(@home, "projects", "sample-project")
    backup = File.join(@home, ".runtime", "legacy-project-backups", "sample-project")
    FileUtils.mkdir_p([legacy_path, backup])
    write_legacy_project(layout: "wrapper", wrapper: legacy_path)

    error = assert_raises(ArgumentError) { project_registry.upgrade_registry(apply: true) }

    assert_includes error.message, "backup already exists"
    assert File.directory?(legacy_path)
    assert registry_payload.dig("projects", "sample-project").key?("wrapper")
  end

  def test_relink_refuses_a_repository_with_a_different_origin
    project_registry.onboard(repository: @repository, key: "sample-project", apply: true)
    another = create_repository("different-project", "https://example.invalid/different-project.git")

    error = assert_raises(ArgumentError) do
      project_registry.relink(repository: another, key: "sample-project", apply: true)
    end
    assert_includes error.message, "remote does not match"
  end

  private

  def project_registry
    AgentOS::ProjectRegistry.new(source: @source, home: @home)
  end

  def registry_payload
    YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
  end

  def write_legacy_project(layout:, wrapper:)
    payload = registry_payload
    payload.fetch("projects")["sample-project"] = {
      "display_name" => "Sample Project",
      "status" => "active",
      "layout" => layout,
      "aliases" => [],
      "wrapper" => File.expand_path(wrapper),
      "repositories" => [
        {
          "id" => "sample-project",
          "path" => File.realpath(@repository),
          "role" => "primary",
          "source_of_truth" => "unknown",
          "primary_branch" => "main",
          "remotes" => { "origin" => "https://example.invalid/sample-project.git" }
        }
      ]
    }
    File.write(File.join(@home, "config", "projects.yaml"), YAML.dump(payload))
  end

  def create_repository(name, remote)
    path = File.join(@temporary, name)
    git("init", "-b", "main", path)
    git("-C", path, "config", "user.name", "Agent OS Test")
    git("-C", path, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(path, "README.md"), "# #{name}\n")
    git("-C", path, "add", "README.md")
    git("-C", path, "commit", "-m", "Initial commit")
    git("-C", path, "remote", "add", "origin", remote) if remote
    path
  end

  def git(*arguments)
    _stdout, stderr, status = Open3.capture3("git", *arguments)
    assert status.success?, stderr
  end

  def git_output(*arguments)
    stdout, stderr, status = Open3.capture3("git", *arguments)
    assert status.success?, stderr
    stdout.strip
  end
end
