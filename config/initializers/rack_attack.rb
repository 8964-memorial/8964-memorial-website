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

  # The app sits behind Cloudflare; req.ip resolves to a Cloudflare edge address
  # unless Cloudflare's ranges are in trusted_proxies. Prefer the visitor's real
  # IP from the CF-Connecting-IP header, with req.ip as a fallback for direct hits.
  def self.client_ip(req)
    req.env['HTTP_CF_CONNECTING_IP'] || req.ip
  end

  # Block IPs the controller has flagged as repeat attackers (see
  # PagesController#flag_security_offender). The ban is written by Fail2Ban
  # against the "attack:<ip>" discriminator and lasts 24h.
  blocklist("banned for repeat attack attempts") do |req|
    Rack::Attack::Fail2Ban.banned?("attack:#{client_ip(req)}")
  end

  # Never throttle the monitoring health check.
  safelist("allow/health") do |req|
    req.path == "/health"
  end

  # Throttle comment submissions per IP: at most 5 per minute.
  throttle("say/ip/minute", limit: 5, period: 60) do |req|
    client_ip(req) if req.post? && req.path == "/say"
  end

  # And a per-day ceiling per IP to stop slow-drip flooding.
  throttle("say/ip/day", limit: 30, period: 1.day) do |req|
    client_ip(req) if req.post? && req.path == "/say"
  end

  # General safety net against request floods (any path) per IP.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    client_ip(req) unless req.path == "/health"
  end

  # Response returned to throttled clients.
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/plain; charset=utf-8" },
      ["留言過於頻繁，請稍後再試。\n"]
    ]
  end

  # Response returned to clients that hit the attack blocklist.
  self.blocklisted_responder = lambda do |_request|
    [
      403,
      { "Content-Type" => "text/plain; charset=utf-8" },
      ["拒絕存取。\n"]
    ]
  end
end
