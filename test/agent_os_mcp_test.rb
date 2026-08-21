# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

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
      assert_equal "0.6.0", initialize_result.dig("result", "serverInfo", "version")

      tool_list = request(stdin, stdout, 2, "tools/list")
      assert_equal 9, tool_list.dig("result", "tools").length
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_onboard_project" }
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_upgrade_project_registry" }
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_relink_project" }
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_label_task" }
      assert tool_list.dig("result", "tools").any? { |tool| tool.fetch("name") == "agent_os_attach_source" }
      task_mutations = tool_list.dig("result", "tools").select do |tool|
        %w[agent_os_label_task agent_os_attach_source agent_os_update_task].include?(tool.fetch("name"))
      end
      task_mutations.each do |tool|
        assert_equal %w[id taskId task_id], tool.dig("inputSchema", "properties").keys.grep(/\A(?:id|taskId|task_id)\z/).sort
        refute tool.fetch("inputSchema").key?("anyOf")
        refute tool.fetch("inputSchema").key?("allOf")
      end

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

  def test_server_lists_a_local_only_project
    project = File.join(@temporary, "local-only")
    FileUtils.mkdir_p(project)
    _, stderr, status = Open3.capture3(
      File.join(@source, "bin", "agent-os"),
      "sync-codex-projects", "--source", @source, "--home", @home,
      "--directory", project, "--apply", "--json"
    )
    assert status.success?, stderr

    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, server_stderr, wait_thread|
      projects = request(stdin, stdout, 1, "tools/call", { "name" => "agent_os_list_projects", "arguments" => {} })
      local_project = projects.dig("result", "structuredContent", "projects").find do |entry|
        entry.fetch("key") == "local-only"
      end

      assert_equal File.realpath(project), local_project.fetch("root")
      assert_empty local_project.fetch("repositories")

      stdin.close
      assert wait_thread.value.success?, server_stderr.read
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
    git(repository, "remote", "add", "origin", "https://example.invalid/mcp-project.git")

    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      preview = request(
        stdin,
        stdout,
        1,
        "tools/call",
        { "name" => "agent_os_onboard_project", "arguments" => { "repositoryPath" => repository } }
      )
      assert_equal "create", preview.dig("result", "structuredContent", "action")
      assert_equal File.realpath(repository), preview.dig("result", "structuredContent", "project", "root")
      refute File.exist?(File.join(@home, "projects"))

      applied = request(
        stdin,
        stdout,
        2,
        "tools/call",
        { "name" => "agent_os_onboard_project", "arguments" => { "repositoryPath" => repository, "apply" => true } }
      )
      assert_equal "created", applied.dig("result", "structuredContent", "action")
      refute File.exist?(File.join(@home, "projects"))
      registry = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
      assert_equal File.realpath(repository), registry.dig("projects", "mcp-project", "root")
      refute registry.dig("projects", "mcp-project").key?("layout")
      refute registry.dig("projects", "mcp-project").key?("wrapper")

      moved_repository = File.join(@temporary, "mcp-project-moved")
      FileUtils.mv(repository, moved_repository)
      relink_preview = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_relink_project",
          "arguments" => { "key" => "mcp-project", "repositoryPath" => moved_repository }
        }
      )
      assert_equal "replace", relink_preview.dig("result", "structuredContent", "action")

      relink_applied = request(
        stdin,
        stdout,
        4,
        "tools/call",
        {
          "name" => "agent_os_relink_project",
          "arguments" => { "key" => "mcp-project", "repositoryPath" => moved_repository, "apply" => true }
        }
      )
      assert_equal "relinked", relink_applied.dig("result", "structuredContent", "action")
      registry = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
      assert_equal File.realpath(moved_repository), registry.dig("projects", "mcp-project", "repositories", 0, "path")
      assert_equal File.realpath(moved_repository), registry.dig("projects", "mcp-project", "root")

      legacy_path = File.join(@home, "projects", "mcp-project")
      FileUtils.mkdir_p(legacy_path)
      File.write(File.join(legacy_path, "README.md"), "legacy context\n")
      registry.dig("projects", "mcp-project")["layout"] = "wrapper"
      registry.dig("projects", "mcp-project")["wrapper"] = legacy_path
      File.write(File.join(@home, "config", "projects.yaml"), YAML.dump(registry))

      upgrade_preview = request(
        stdin,
        stdout,
        5,
        "tools/call",
        {
          "name" => "agent_os_upgrade_project_registry",
          "arguments" => {}
        }
      )
      assert_equal "upgrade", upgrade_preview.dig("result", "structuredContent", "action")
      assert File.exist?(legacy_path)

      upgrade_applied = request(
        stdin,
        stdout,
        6,
        "tools/call",
        {
          "name" => "agent_os_upgrade_project_registry",
          "arguments" => { "apply" => true }
        }
      )
      assert_equal "upgraded", upgrade_applied.dig("result", "structuredContent", "action")
      refute File.exist?(legacy_path), "legacy path still exists after upgrade: #{Dir.glob(File.join(@home, '**', '*'), File::FNM_DOTMATCH).sort.inspect}; result=#{upgrade_applied.inspect}"
      assert_equal "legacy context\n", File.read(File.join(@home, ".runtime", "legacy-project-backups", "mcp-project", "README.md"))
      registry = YAML.safe_load(File.read(File.join(@home, "config", "projects.yaml")), aliases: false)
      refute registry.dig("projects", "mcp-project").key?("layout")
      refute registry.dig("projects", "mcp-project").key?("wrapper")

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

  def test_server_onboarding_reconciles_only_reviewed_slack_channel_ids
    repository = File.join(@temporary, "example-product-next")
    system("git", "init", "-b", "main", repository, out: File::NULL, err: File::NULL) or flunk "repo init failed"
    git(repository, "config", "user.name", "Agent OS Test")
    git(repository, "config", "user.email", "agent-os@example.invalid")
    File.write(File.join(repository, "README.md"), "# Example Product\n")
    git(repository, "add", "README.md")
    git(repository, "commit", "-m", "Initial commit")
    git(repository, "remote", "add", "origin", "https://example.invalid/example-product-next.git")

    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      created = request(
        stdin,
        stdout,
        1,
        "tools/call",
        {
          "name" => "agent_os_create_task",
          "arguments" => {
            "title" => "Cover example product handoff",
            "goal" => "Keep the Slack work visible",
            "nextAction" => "Confirm ownership"
          }
        }
      )
      task_id = created.dig("result", "structuredContent", "task", "id")
      request(
        stdin,
        stdout,
        2,
        "tools/call",
        {
          "name" => "agent_os_label_task",
          "arguments" => {
            "taskId" => task_id,
            "key" => "slack:CEXAMPLE",
            "name" => "#project-example-product-int",
            "kind" => "slack_channel"
          }
        }
      )

      preview = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_onboard_project",
          "arguments" => { "repositoryPath" => repository }
        }
      )
      assert_equal "CEXAMPLE", preview.dig(
        "result", "structuredContent", "reconciliation", "suggested_channels", 0, "id"
      )
      assert_empty preview.dig("result", "structuredContent", "reconciliation", "selected_channels")

      selected_preview = request(
        stdin,
        stdout,
        4,
        "tools/call",
        {
          "name" => "agent_os_onboard_project",
          "arguments" => {
            "repositoryPath" => repository,
            "slackChannelIds" => ["CEXAMPLE"]
          }
        }
      )
      assert_equal [task_id], selected_preview.dig(
        "result", "structuredContent", "reconciliation", "task_assignments"
      ).map { |assignment| assignment.fetch("task_id") }

      applied = request(
        stdin,
        stdout,
        5,
        "tools/call",
        {
          "name" => "agent_os_onboard_project",
          "arguments" => {
            "repositoryPath" => repository,
            "slackChannelIds" => ["CEXAMPLE"],
            "apply" => true
          }
        }
      )
      assert_equal "created", applied.dig("result", "structuredContent", "action")

      projects = request(stdin, stdout, 6, "tools/call", { "name" => "agent_os_list_projects", "arguments" => {} })
      example_product = projects.dig("result", "structuredContent", "projects").find do |project|
        project.fetch("key") == "example-product-next"
      end
      assert_equal "CEXAMPLE", example_product.dig("slack_channels", 0, "id")

      tasks = request(stdin, stdout, 7, "tools/call", { "name" => "agent_os_list_tasks", "arguments" => {} })
      task = tasks.dig("result", "structuredContent", "tasks").find { |candidate| candidate.fetch("id") == task_id }
      assert_equal ["example-product-next"], task.fetch("projects")
      assert_equal "#project-example-product-int", task.dig("labels", 0, "name")

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_updates_completion_follow_up_separately_from_lifecycle
    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      created = request(
        stdin,
        stdout,
        1,
        "tools/call",
        {
          "name" => "agent_os_create_task",
          "arguments" => {
            "title" => "Verify completion follow-up",
            "goal" => "Keep completed work actionable",
            "nextAction" => "Finish the outcome"
          }
        }
      )
      task_id = created.dig("result", "structuredContent", "task", "id")
      refute_nil task_id

      completed = request(
        stdin,
        stdout,
        2,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "taskId" => task_id, "status" => "done" }
        }
      )
      assert_equal "done", completed.dig("result", "structuredContent", "task", "status")

      follow_up = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "taskId" => task_id, "completionFollowUp" => "sent" }
        }
      )
      assert_equal "sent", follow_up.dig("result", "structuredContent", "task", "completion", "follow_up_status")
      assert_equal 1, follow_up.dig("result", "structuredContent", "eventDelta")

      invalid_combination = request(
        stdin,
        stdout,
        4,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => {
            "taskId" => task_id,
            "status" => "review",
            "completionFollowUp" => "pending"
          }
        }
      )
      assert invalid_combination.dig("result", "isError")
      assert_match(
        /must be updated separately/,
        invalid_combination.dig("result", "structuredContent", "error")
      )

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_accepts_task_id_aliases_and_rejects_conflicts
    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      created = request(
        stdin,
        stdout,
        1,
        "tools/call",
        {
          "name" => "agent_os_create_task",
          "arguments" => {
            "title" => "Verify task ID aliases",
            "goal" => "Keep task mutation calls compatible",
            "nextAction" => "Exercise each supported identifier field"
          }
        }
      )
      task_id = created.dig("result", "structuredContent", "task", "id")

      snake_case = request(
        stdin,
        stdout,
        2,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "task_id" => task_id, "summary" => "Updated through task_id" }
        }
      )
      assert_equal "Updated through task_id", snake_case.dig("result", "structuredContent", "task", "summary")

      short_alias = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "id" => task_id, "nextAction" => "Continue through id" }
        }
      )
      assert_equal "Continue through id", short_alias.dig("result", "structuredContent", "task", "nextAction")

      matching_aliases = request(
        stdin,
        stdout,
        4,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "taskId" => task_id, "task_id" => task_id, "status" => "active" }
        }
      )
      assert_equal "active", matching_aliases.dig("result", "structuredContent", "task", "status")

      conflicting_aliases = request(
        stdin,
        stdout,
        5,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "taskId" => task_id, "id" => "another_task", "status" => "review" }
        }
      )
      assert conflicting_aliases.dig("result", "isError")
      assert_match(/Conflicting task ID fields: taskId, id/, conflicting_aliases.dig("result", "structuredContent", "error"))

      missing_alias = request(
        stdin,
        stdout,
        6,
        "tools/call",
        {
          "name" => "agent_os_update_task",
          "arguments" => { "summary" => "Must not apply without an exact task ID" }
        }
      )
      assert missing_alias.dig("result", "isError")
      assert_match(/One of taskId, task_id, or id is required/, missing_alias.dig("result", "structuredContent", "error"))

      tasks = request(stdin, stdout, 7, "tools/call", { "name" => "agent_os_list_tasks", "arguments" => {} })
      task = tasks.dig("result", "structuredContent", "tasks").find { |candidate| candidate.fetch("id") == task_id }
      assert_equal "active", task.fetch("status")
      assert_equal 4, task.fetch("eventCount")

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_labels_an_unassigned_task_without_project_routing
    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      created = request(
        stdin,
        stdout,
        1,
        "tools/call",
        {
          "name" => "agent_os_create_task",
          "arguments" => {
            "title" => "Review a client request",
            "goal" => "Keep Slack-only work visible",
            "nextAction" => "Review the source thread"
          }
        }
      )
      task_id = created.dig("result", "structuredContent", "task", "id")

      labeled = request(
        stdin,
        stdout,
        2,
        "tools/call",
        {
          "name" => "agent_os_label_task",
          "arguments" => {
            "task_id" => task_id,
            "key" => "slack:C0CLIENT01",
            "name" => "#client-checks",
            "kind" => "slack_channel"
          }
        }
      )
      assert_equal "#client-checks", labeled.dig("result", "structuredContent", "task", "labels", 0, "name")
      assert_equal 1, labeled.dig("result", "structuredContent", "eventDelta")

      repeated = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_label_task",
          "arguments" => {
            "taskId" => task_id,
            "key" => "slack:C0CLIENT01",
            "name" => "#client-checks",
            "kind" => "slack_channel"
          }
        }
      )
      assert_equal 0, repeated.dig("result", "structuredContent", "eventDelta")

      tasks = request(stdin, stdout, 4, "tools/call", { "name" => "agent_os_list_tasks", "arguments" => {} })
      listed = tasks.dig("result", "structuredContent", "tasks").find { |task| task.fetch("id") == task_id }
      assert_empty listed.fetch("projects")
      assert_equal "slack:C0CLIENT01", listed.dig("labels", 0, "key")

      stdin.close
      assert wait_thread.value.success?, stderr.read
    end
  end

  def test_server_attaches_and_refreshes_a_short_slack_source_title
    with_server("AGENT_OS_SOURCE_ROOT" => @source, "AGENT_OS_HOME" => @home) do |stdin, stdout, stderr, wait_thread|
      created = request(
        stdin,
        stdout,
        1,
        "tools/call",
        {
          "name" => "agent_os_create_task",
          "arguments" => {
            "title" => "Review a client thread",
            "goal" => "Keep Slack work recognizable",
            "nextAction" => "Open the source thread"
          }
        }
      )
      task_id = created.dig("result", "structuredContent", "task", "id")
      source_value = "https://example.slack.com/archives/C0CLIENT01/p1786232231519149"

      attached = request(
        stdin,
        stdout,
        2,
        "tools/call",
        {
          "name" => "agent_os_attach_source",
          "arguments" => {
            "id" => task_id,
            "kind" => "slack_threads",
            "value" => source_value,
            "title" => "*Please* review the <https://example.invalid/brief|client brief>"
          }
        }
      )
      assert_equal "Please review the client brief", attached.dig("result", "structuredContent", "task", "sources", 0, "title")
      assert_equal 1, attached.dig("result", "structuredContent", "eventDelta")

      repeated = request(
        stdin,
        stdout,
        3,
        "tools/call",
        {
          "name" => "agent_os_attach_source",
          "arguments" => {
            "taskId" => task_id,
            "kind" => "slack_threads",
            "value" => source_value,
            "title" => "Please review the client brief"
          }
        }
      )
      assert_equal 0, repeated.dig("result", "structuredContent", "eventDelta")

      refreshed = request(
        stdin,
        stdout,
        4,
        "tools/call",
        {
          "name" => "agent_os_attach_source",
          "arguments" => {
            "taskId" => task_id,
            "kind" => "slack_threads",
            "value" => source_value,
            "title" => "Please review the revised client brief"
          }
        }
      )
      assert_equal "Please review the revised client brief", refreshed.dig("result", "structuredContent", "task", "sources", 0, "title")
      assert_equal 1, refreshed.dig("result", "structuredContent", "eventDelta")

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
