# frozen_string_literal: true

# YARD rescues an exception raised by a handler and only logs `[error]: ...`, so a spec that runs
# crashing code still passes. This module records every message that YARD logs at ERROR or above,
# whatever the log level, so that spec_helper.rb can fail the example on it.
module YardErrors
  # @return [Array<String>] The error messages logged since the start of the example.
  def self.messages
    @messages ||= []
  end

  # Starts recording. A method, because YARD warns about a top-level `prepend` on YARD's own
  # class when it documents the specs.
  # @return [void]
  def self.install
    YARD::Logger.prepend(Recorder)
  end

  # Prepended to YARD::Logger; every log method goes through #log.
  module Recorder
    # @param severity [Integer] One of the YARD::Logger::Severity constants.
    # @param message [String]
    # @return [void]
    def log(severity, message)
      YardErrors.messages << message if severity >= YARD::Logger::Severity::ERROR
      super
    end
  end
end
