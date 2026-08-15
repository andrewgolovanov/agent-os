# frozen_string_literal: true

Dir.glob(File.join(__dir__, "*_test.rb")).sort.each { |test| require test }
