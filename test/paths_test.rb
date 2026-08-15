# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/agent_os/paths"

class PathsTest < Minitest::Test
  ENVIRONMENT_KEYS = %w[
    AGENT_OS_HOME
    AGENT_OS_HOME_POINTER
    AGENT_OS_SOURCE_ROOT
    HOME
    WORKSPACE_ROOT
  ].freeze

  def setup
    @temporary = Dir.mktmpdir("agent-os-paths-")
    @original_environment = ENVIRONMENT_KEYS.to_h { |key| [key, ENV[key]] }
  end

  def teardown
    @original_environment.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    AgentOS::Paths.reset!
    FileUtils.remove_entry(@temporary) if File.exist?(@temporary)
  end

  def test_home_root_uses_active_pointer_without_explicit_environment
    source = File.join(@temporary, "source")
    home = File.join(@temporary, "private-home")
    pointer = File.join(@temporary, ".config", "agent-os", "home")
    FileUtils.mkdir_p([source, home, File.dirname(pointer)])
    File.write(pointer, "#{home}\n")

    ENV["HOME"] = @temporary
    ENV["AGENT_OS_SOURCE_ROOT"] = source
    ENV.delete("AGENT_OS_HOME")
    ENV.delete("AGENT_OS_HOME_POINTER")
    ENV.delete("WORKSPACE_ROOT")
    AgentOS::Paths.reset!

    assert_equal home, AgentOS::Paths.home_root
  end

  def test_explicit_home_takes_precedence_over_active_pointer
    source = File.join(@temporary, "source")
    active_home = File.join(@temporary, "active-home")
    explicit_home = File.join(@temporary, "explicit-home")
    pointer = File.join(@temporary, "home-pointer")
    FileUtils.mkdir_p([source, active_home, explicit_home])
    File.write(pointer, "#{active_home}\n")

    ENV["AGENT_OS_SOURCE_ROOT"] = source
    ENV["AGENT_OS_HOME"] = explicit_home
    ENV["AGENT_OS_HOME_POINTER"] = pointer
    ENV.delete("WORKSPACE_ROOT")
    AgentOS::Paths.reset!

    assert_equal explicit_home, AgentOS::Paths.home_root
  end

  def test_invalid_active_pointer_preserves_legacy_source_fallback
    source = File.join(@temporary, "legacy-root")
    pointer = File.join(@temporary, "home-pointer")
    FileUtils.mkdir_p(source)
    File.write(pointer, "relative/home\n")

    ENV["AGENT_OS_SOURCE_ROOT"] = source
    ENV["AGENT_OS_HOME_POINTER"] = pointer
    ENV.delete("AGENT_OS_HOME")
    ENV.delete("WORKSPACE_ROOT")
    AgentOS::Paths.reset!

    assert_equal source, AgentOS::Paths.home_root
  end
end
