require "test_helper"
require "puma"
require "puma/configuration"

# config/puma.rb is the production web-server config; a typo there takes the
# whole site down (which is exactly the class of outage that motivated the
# unicorn -> puma switch). These tests load the real config file under each
# RAILS_ENV and assert the resolved options, without starting a server.
class PumaConfigTest < ActiveSupport::TestCase
  PUMA_RB = Rails.root.join("config", "puma.rb").to_s

  def load_options(rails_env, extra_env = {})
    saved = ENV.to_hash
    ENV["RAILS_ENV"] = rails_env
    extra_env.each { |k, v| ENV[k] = v }
    conf = Puma::Configuration.new(config_files: [PUMA_RB])
    conf.load
    conf.options
  ensure
    ENV.replace(saved)
  end

  test "production runs a preloaded 4-worker cluster bound to a unix socket" do
    opts = load_options("production", "MEMORIAL_PUMA_BIND" => "unix:///tmp/puma_config_test.sock")
    assert_equal 4, opts[:workers]
    assert_equal true, opts[:preload_app]
    assert_equal ["unix:///tmp/puma_config_test.sock"], opts[:binds]
    assert_equal 30, opts[:worker_timeout]
    assert_equal "production", opts[:environment]
  end

  test "production binds the nginx socket path by default" do
    opts = load_options("production")
    bind = opts[:binds].first
    assert bind.start_with?("unix://"), "expected a unix socket bind, got #{bind.inspect}"
    assert_includes bind, "unicorn.sock"
  end

  test "production worker count is overridable via WEB_CONCURRENCY" do
    opts = load_options("production", "WEB_CONCURRENCY" => "2", "MEMORIAL_PUMA_BIND" => "unix:///tmp/x.sock")
    assert_equal 2, opts[:workers]
  end

  test "development listens on TCP and does not preload" do
    opts = load_options("development")
    assert opts[:binds].any? { |b| b.start_with?("tcp://") },
           "expected a tcp bind, got #{opts[:binds].inspect}"
    refute_equal true, opts[:preload_app]
  end
end
