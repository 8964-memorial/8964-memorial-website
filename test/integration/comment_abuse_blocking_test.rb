require "test_helper"

# Exercises the rack-attack Fail2Ban path end to end: repeated attack
# submissions from one IP get the IP blocked at the middleware layer. Rack-attack
# is disabled in the rest of the suite, so this class turns it on with an
# isolated, process-unique cache and restores everything in teardown.
class CommentAbuseBlockingTest < ActionDispatch::IntegrationTest
  ATTACKER_IP = "203.0.113.77".freeze
  ATTACK_PARAMS = { message: { name: "x", content: "<script>x</script>" } }.freeze

  def setup
    @original_enabled = Rack::Attack.enabled
    @original_store = Rack::Attack.cache.store
    @original_memorial = Rails.application.config.memorial

    @tmp_cache = Rails.root.join("tmp", "rack_attack_test_#{Process.pid}").to_s
    Rack::Attack.cache.store = ActiveSupport::Cache::FileStore.new(@tmp_cache)
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = true
    Rails.application.config.memorial = { features: { commenting_enabled: true } }
  end

  def teardown
    Rails.application.config.memorial = @original_memorial
    Rack::Attack.enabled = @original_enabled
    Rack::Attack.cache.store.clear
    Rack::Attack.cache.store = @original_store
    FileUtils.rm_rf(@tmp_cache)
  end

  test "bans an IP after repeated attack attempts and blocks further requests" do
    headers = { "CF-Connecting-IP" => ATTACKER_IP }

    # The ban is set by the controller after the middleware runs, so the first
    # three attack POSTs are still silently dropped (302), not yet blocked.
    3.times do
      assert_no_difference("Message.count") do
        post say_path, params: ATTACK_PARAMS, headers: headers
      end
      assert_response :redirect
    end

    # With the IP now banned (Fail2Ban maxretry: 3), any further request from it
    # is rejected at the rack-attack layer before reaching the controller.
    get root_path, headers: headers
    assert_response :forbidden

    # A different IP is unaffected.
    get root_path, headers: { "CF-Connecting-IP" => "198.51.100.9" }
    assert_response :success
  end
end
