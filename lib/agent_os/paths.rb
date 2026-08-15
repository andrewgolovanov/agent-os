# frozen_string_literal: true

module AgentOS
  module Paths
    module_function

    def source_root
      @source_root ||= resolve_root(
        ENV["AGENT_OS_SOURCE_ROOT"],
        File.expand_path("../..", __dir__),
        "AGENT_OS_SOURCE_ROOT"
      )
    end

    def home_root
      @home_root ||= resolve_root(
        ENV["AGENT_OS_HOME"] || ENV["WORKSPACE_ROOT"] || active_home_root,
        source_root,
        "AGENT_OS_HOME"
      )
    end

    def config_root
      File.join(home_root, "config")
    end

    def work_root
      File.join(home_root, "work")
    end

    def runtime_root
      File.join(home_root, ".runtime")
    end

    def reset!
      @source_root = nil
      @home_root = nil
    end

    def active_home_root
      pointer = ENV["AGENT_OS_HOME_POINTER"].to_s.strip
      if pointer.empty?
        user_home = ENV["HOME"].to_s.strip
        user_home = Dir.home if user_home.empty?
        pointer = File.join(user_home, ".config", "agent-os", "home")
      end
      return nil unless File.file?(pointer)

      value = File.read(pointer).strip
      return nil unless value.start_with?(File::SEPARATOR) && value != File::SEPARATOR

      value
    rescue SystemCallError
      nil
    end

    def resolve_root(configured, fallback, label)
      value = configured.to_s.strip.empty? ? fallback : configured
      raise ArgumentError, "#{label} must be an absolute path" unless value.start_with?(File::SEPARATOR)

      expanded = File.expand_path(value)
      raise ArgumentError, "#{label} cannot be the filesystem root" if expanded == File::SEPARATOR

      expanded
    end
    private_class_method :resolve_root
  end
end
