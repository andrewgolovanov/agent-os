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
      assert_equal 4, tool_list.dig("result", "tools").length

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
