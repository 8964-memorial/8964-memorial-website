# Puma configuration.
#
# Puma replaced unicorn as the production server: unicorn 6.1.0 (the last
# release) crashes on Rack 3 + Ruby 3.4 because it does `value =~ /\n/` on each
# response header value, but Rack 3 hands Set-Cookie back as an Array and Ruby
# 3.4 removed Object#=~ — so every cookie-setting response 500s. Puma 6 natively
# supports Rack 3.

# Puma serves each request from a thread pool. The thread count should match the
# Active Record pool size (config/database.yml) so threads aren't starved.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

environment ENV.fetch("RAILS_ENV") { "development" }

if ENV.fetch("RAILS_ENV", "development") == "production"
  # Production runs behind nginx over a unix socket (no public TCP listener).
  # Bind the same socket path nginx's upstream already points at so the nginx
  # config doesn't need to change. Override with MEMORIAL_PUMA_BIND if the
  # deploy path differs.
  bind ENV.fetch("MEMORIAL_PUMA_BIND") {
    "unix:///srv/8964-memorial-website/shared/tmp/sockets/unicorn.sock"
  }

  # Cluster mode: fork worker processes (matches the old unicorn 4 workers).
  # preload_app! gives copy-on-write memory savings; Rails reconnects
  # ActiveRecord automatically after fork (ForkTracker), so no on_worker_boot
  # reconnect is needed on Rails 7.2.
  #
  # Restart note: preload_app! is incompatible with phased restart (SIGUSR1).
  # Use a hot restart (SIGUSR2) or `systemctl restart` to pick up new code.
  workers ENV.fetch("WEB_CONCURRENCY") { 4 }
  preload_app!

  # Kill and replace a worker that hangs this long (matches old unicorn timeout).
  worker_timeout ENV.fetch("WEB_WORKER_TIMEOUT") { 30 }.to_i

  pidfile ENV.fetch("PIDFILE") {
    "/srv/8964-memorial-website/shared/tmp/pids/puma.pid"
  }
else
  # Development / test: listen on TCP for `bin/rails server`.
  port ENV.fetch("PORT") { 3000 }
  pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

  # Don't terminate a worker you're debugging.
  worker_timeout 3600

  # Allow puma to be restarted by `bin/rails restart`.
  plugin :tmp_restart
end
