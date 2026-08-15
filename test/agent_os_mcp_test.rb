# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

class AgentOSMCPTest < Minitest::Test
  def setup
    skip "Node.js is required" unless system("node", "--version", out: File::NULL, err: File::NULL)

    @source = File.expand_path("..", __dir__)
    @temporary = Dir.mktmpdir("agent-os-mcp-")
    @home = File.join(@temporary, "home")
    executable = File.join(@source, "bin", "agent-os")
    _, stderr, status = Open3.capture3(executable, "init", "--source", @source, "--home", @home, "--apply")
    raise stderr unless status.success?
  end

  def teardown
    FileUtils.remove_entry(@temporary) if @temporary && File.exist?(@temporary)
  end

  def test_server_uses_separate_source_and_home_roots
    environment = { "AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home }

    with_server(environment) do |stdin, stdout, stderr, wait_thread|
      initialize_result = request(stdin, stdout, 1, "initialize", { "protocolVersion" => "2025-11-25" })
      assert_equal "agent-os", initialize_result.dig("result", "serverInfo", "name")

      tool_list = request(stdin, stdout, 2, "tools/list")
      assert_equal 5, tool_list.dig("result", "tools").length
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_onboard_project" }

      tasks = request(
        stdin,
        stdout,
        3,
        "tools/call",
        { "name" => "agent_os_list_tasks", "arguments" => {} }
      )
      assert_equal [], tasks.dig("result", "structuredContent", "tasks")

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_onboards_an_existing_repository_preview_first
    repository = File.join(@temporary, "mcp-project")
    system("git", "init", "-b", "main", repository, out: File::NULL, err: File::NULL) or flunk "repo init failed"
    git(repository, "config", "user.name", "Agent OS Test")
    git(repository, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(repository, "README.md"), "# MCP project\n")
    git(repository, "add", "README.md")
    git(repository, "commit", "-m", "Initial commit")

    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      preview = request(
        stdin,
        stdout,
        1,
        "tools/call",
        { "name" => "agent_os_onboard_project", "arguments" => { "repositoryPath" => repository } }
      )
      assert_equal "create", preview.dig("result", "structuredContent", "action")
      refute File.exist?(File.join(@home, "projects", "mcp-project"))

      applied = request(
        stdin,
        stdout,
        2,
        "tools/call",
        { "name" => "agent_os_onboard_project", "arguments" => { "repositoryPath" => repository, "apply" => true } }
      )
      assert_equal "created", applied.dig("result", "structuredContent", "action")
      assert File.file?(File.join(@home, "projects", "mcp-project", "project.yaml"))

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_bootstraps_without_a_source_checkout_override
    isolated_user_home = File.join(@temporary, "isolated-user")
    FileUtils.mkdir_p(isolated_user_home)
    bundled_runtime = File.join(@source, "plugins", "agent-os", "runtime")

    with_server(
      "HOME" => isolated_user_home,
      "AGENT_OS_HOME" => nil,
      "AGENT_OS_SOURCE_ROOT" => nil,
      "WORKSPACE_CONSOLE_ROOT" => nil,
      "WORKSPACE_CONSOLE_SOURCE_ROOT" => nil,
      "AGENT_OS_HOME_POINTER" => nil
    ) do |stdin, stdout, stderr, wait_thread|
      tasks = request(stdin, stdout, 1, "tools/call", { "name" => "agent_os_list_tasks", "arguments" => {} })
      assert_equal [], tasks.dig("result", "structuredContent", "tasks")
      private_home = File.join(isolated_user_home, ".agent-os")
      assert File.file?(File.join(private_home, "config", "projects.yaml"))
      assert_equal "#{File.realpath(bundled_runtime)}\n", File.read(File.join(private_home, "source-path"))

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_discovers_activated_non_default_home
    executable = File.join(@source, "bin", "agent-os")
    _, stderr, status = Open3.capture3(
      { "HOME" => @temporary },
      executable, "activate", "--home", @home, "--apply"
    )
    assert status.success?, stderr

    pointer = File.join(@temporary, ".config", "agent-os", "home")
    with_server(
      "AGENT_OS_HOME" => nil,
      "WORKSPACE_CONSOLE_ROOT" => nil,
      "AGENT_OS_HOME_POINTER" => pointer
    ) do |stdin, stdout, stderr_io, wait_thread|
      tasks = request(
        stdin,
        stdout,
        1,
        "tools/call",
        { "name" => "agent_os_list_tasks", "arguments" => {} }
      )
      assert_equal [], tasks.dig("result", "structuredContent", "tasks")
      stdin.close
      assert wait_thread.value.success?, stderr_io.read
    end
  end

  private

  def git(directory, *arguments)
    _stdout, stderr, status = Open3.capture3("git", *arguments, chdir: directory)
    assert status.success?, stderr
  end

  def request(stdin, stdout, id, method, params = nil)
    message = { "jsonrpc" => "2.0", "id" => id, "method" => method }
    message["params"] = params if params
    stdin.puts(JSON.generate(message))
    stdin.flush
    JSON.parse(stdout.gets)
  end

  def with_server(environment, &block)
    server = File.join(@source, "plugins", "agent-os", "mcp", "server.mjs")
    Open3.popen3(environment, "node", server, &block)
  end
end
