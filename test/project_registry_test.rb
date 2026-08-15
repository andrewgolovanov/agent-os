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
    @repository = File.join(@temporary, "sample-project")
    executable = File.join(@source, "bin", "agent-os")
    _stdout, stderr, status = Open3.capture3(
      executable, "init", "--source", @source, "--home", @home, "--apply"
    )
    raise stderr unless status.success?

    git("init", "-b", "main", @repository)
    git("-C", @repository, "config", "user.name", "Agent OS Test")
    git("-C", @repository, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(@repository, "README.md"), "# Sample\n")
    git("-C", @repository, "add", "README.md")
    git("-C", @repository, "commit", "-m", "Initial commit")
    git("-C", @repository, "remote", "add", "origin", "https://example.invalid/sample-project.git")
  end

  def teardown
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_onboarding_is_preview_first_and_preserves_repository
    registry = AgentOS::ProjectRegistry.new(source: @source, home: @home)
    before_head = git_output("-C", @repository, "rev-parse", "HEAD")
    before_status = git_output("-C", @repository, "status", "--porcelain")

    preview = registry.onboard(repository: @repository, display_name: "Sample Project")

    assert_equal "create", preview.fetch(:action)
    assert_equal false, preview.fetch(:applied)
    assert_equal "sample-project", preview.dig(:project, :key)
    assert_equal "wrapper", preview.dig(:project, :layout)
    refute File.exist?(File.join(@home, "projects", "sample-project"))
    projects = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
    assert_equal({}, projects.fetch("projects"))

    created = registry.onboard(repository: @repository, display_name: "Sample Project", apply: true)

    assert_equal "created", created.fetch(:action)
    assert_equal true, created.fetch(:applied)
    wrapper = File.join(@home, "projects", "sample-project")
    assert File.file?(File.join(wrapper, "AGENTS.md"))
    assert File.file?(File.join(wrapper, "project.yaml"))
    projects = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
    project = projects.dig("projects", "sample-project")
    assert_equal File.realpath(@repository), project.fetch("repositories").first.fetch("path")
    assert_equal before_head, git_output("-C", @repository, "rev-parse", "HEAD")
    assert_equal before_status, git_output("-C", @repository, "status", "--porcelain")

    nested_directory = File.join(@repository, "docs")
    FileUtils.mkdir_p(nested_directory)
    repeated = registry.onboard(repository: nested_directory, apply: true)
    assert_equal "preserve", repeated.fetch(:action)
    assert_equal false, repeated.fetch(:applied)
  end

  def test_onboarding_refuses_a_key_owned_by_another_repository
    registry = AgentOS::ProjectRegistry.new(source: @source, home: @home)
    registry.onboard(repository: @repository, key: "shared-key", apply: true)
    another = File.join(@temporary, "another")
    git("init", "-b", "main", another)
    git("-C", another, "config", "user.name", "Agent OS Test")
    git("-C", another, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(another, "README.md"), "# Another\n")
    git("-C", another, "add", "README.md")
    git("-C", another, "commit", "-m", "Initial commit")

    error = assert_raises(ArgumentError) do
      registry.onboard(repository: another, key: "shared-key", apply: true)
    end
    assert_includes error.message, "already belongs to another repository"
  end

  private

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
