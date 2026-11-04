# frozen_string_literal: true

# Started by `rake spec:coverage`. A run of only some of the specs would not meet the minimum.
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    skip '/spec/'
    minimum_coverage line: 100, branch: 100
  end
end

require 'tempfile'
require 'yard'
require 'rbs'
require 'yard-inline-rbs'
require_relative 'support/yard_errors'

YardErrors.install
YARD::Logger.instance.level = Logger::ERROR

RSpec.configure do |config|
  # The plugin keeps state between parses, like the registry; YARD.parse_string clears none of it.
  config.before do
    YARD::Registry.clear
    YardErrors.messages.clear
    YardInlineRbs::DeclarationSource.clear_cache
    YardInlineRbs::AnnotationWarnings.clear_logged
  end

  # A YARD error is a crash that YARD rescued. Tag an example with :yard_errors when it logs one
  # on purpose.
  config.after do |example|
    expect(YardErrors.messages).to be_empty if !example.metadata[:yard_errors]
  end

  config.raise_errors_for_deprecations!
  config.example_status_persistence_file_path = 'coverage/rspec_example_statuses.txt'
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end
