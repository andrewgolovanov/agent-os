# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

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

  private

  def git(directory, *arguments)
    _stdout, stderr, status = Open3.capture3("git", *arguments, chdir: directory)
    assert status.success?, stderr
  end
end
