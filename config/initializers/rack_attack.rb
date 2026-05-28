# Be sure to restart your server when you modify this file.
#
# Rack::Attack throttles abusive traffic. The memorial comment form (POST /say)
# is a politically sensitive, public endpoint with no CAPTCHA, so it is the main
# target for flooding. See config/initializers/rack_attack.rb in the security plan.

class Rack::Attack
  # Throttling would make the test suite order-dependent and flaky (and the
  # file-backed store below would carry counts across runs), so disable it under
  # test. Throttling stays active in development and production.
  Rack::Attack.enabled = false if Rails.env.test?

  # Unicorn runs multiple worker processes, so an in-memory store would let each
  # worker count independently and undercount real traffic. A file-backed store
  # is shared across workers on a single host. Switch to Redis/Memcached if this
  # ever runs on more than one host.
  Rack::Attack.cache.store =
    ActiveSupport::Cache::FileStore.new(Rails.root.join("tmp", "rack_attack_cache").to_s)

  # Never throttle the monitoring health check.
  safelist("allow/health") do |req|
    req.path == "/health"
  end

  # Throttle comment submissions per IP: at most 5 per minute.
  throttle("say/ip/minute", limit: 5, period: 60) do |req|
    req.ip if req.post? && req.path == "/say"
  end

  # And a per-day ceiling per IP to stop slow-drip flooding.
  throttle("say/ip/day", limit: 30, period: 1.day) do |req|
    req.ip if req.post? && req.path == "/say"
  end

  # General safety net against request floods (any path) per IP.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/health"
  end

  # Response returned to throttled clients.
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/plain; charset=utf-8" },
      ["留言過於頻繁，請稍後再試。\n"]
    ]
  end
end
