# frozen_string_literal: true

require "logger"

module Pakyow
  class Logger < ::Logger
    require "pakyow/logger/colorizer"
    require "pakyow/logger/multilog"
    require "pakyow/logger/timekeeper"

    # Temporarily silences logs, up to +temporary_level+.
    #
    def silence(temporary_level = Logger::ERROR)
      original_level = self.level
      self.level = temporary_level
      yield
    ensure
      self.level = original_level
    end
  end
end
