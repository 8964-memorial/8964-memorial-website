ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run single-process. The rake-task tests (MemorialRakeTest / MemorialClearTest)
  # are not parallel-safe: they share on-disk dirs (static_output/, backup/),
  # global Rake::Task state, and juggle DB connections (clear_all_connections!).
  # Forked workers race on those shared paths. The whole suite runs in ~1s, so
  # parallelization buys nothing here while reintroducing flakiness.
  parallelize(workers: 1)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
