# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Rails 7.2 memorial website for the June 4th (6/4) incident, running on **Ruby 3.4.4**. A simple message board where users can leave memorial messages that are displayed in random order on the main page.

The comment feature (`POST /say`) is politically sensitive and gated by `commenting_enabled?` — kept off by default and only opened around memorial events.

## Core Architecture

- **Single controller**: `PagesController` with three actions:
  - `index` — displays all messages in random order
  - `say` — shows the form for creating a new message
  - `create` — processes message creation and redirects home
- **Simple data model**: one `Message` model with `name` (max 50 chars) and `content` (max 20 chars); `before_save` runs Rails' `sanitize` for XSS belt-and-suspenders.
- **Frontend**: ERB templates + Stimulus/Turbo (Hotwire) via importmap.
- **Database**: MySQL, single `messages` table.
- **Production**: Puma in cluster mode (4 workers, bound to a unix socket) behind nginx → Cloudflare. (Switched from unicorn, which crashes on Rack 3 + Ruby 3.4 — its last release does `header_value =~ /\n/`, but Rack 3 sends `Set-Cookie` as an Array and Ruby 3.4 removed `Object#=~`, so every cookie-setting response 500'd.)

## Deployment context

The app runs behind **Cloudflare Flexible SSL** (browser↔Cloudflare is HTTPS, but Cloudflare→origin is plain HTTP). This drives several config choices:

- `config.assume_ssl = true` together with `config.force_ssl = true` in production. `assume_ssl` lets Rails treat the request as already-encrypted (true for the browser↔Cloudflare hop), so `force_ssl` won't redirect-loop on the HTTP traffic Cloudflare forwards, while cookies still get the `Secure` flag and HSTS is emitted.
- Long-term recommendation: upgrade Cloudflare to **Full (strict)** to encrypt the origin hop too. Not yet done.
- Production DB credentials come from `MEMORIAL_DB_PASSWORD` (and optionally `MEMORIAL_DB_USERNAME`). `config/database.yml` is gitignored; the ENV-based template is in `config/database.yml.default`.
- Comment feature switch: `MEMORIAL_COMMENTING_ENABLED=true` (ENV) or `config/memorial.yml` `features.commenting_enabled`.

## Security mechanisms in place

Already wired up; don't reinvent these when adding features:

- **`rack-attack`** (`config/initializers/rack_attack.rb`) throttles `POST /say` (5/min, 30/day per IP) plus a global safety net (300/5min). Uses a `FileStore` cache (single-host only). **Disabled in test env** — re-enable carefully if you want to test throttling.
- **Honeypot**: a hidden `email_confirmation` field in the say form; if a bot fills it, the controller silently redirects without saving.
- **Attack-pattern detection** (`app/lib/security_filter.rb`): `SecurityFilter.attack_signature` matches `name`/`content` against XSS/SQLi/path-traversal patterns. On a hit, `PagesController#create` **silently drops** the submission (redirects to root exactly like success — no error shown, so the attacker can't probe the filter) and logs `[security][attack-attempt]` with the real client IP + UA.
- **Repeat-offender IP ban**: both honeypot hits and attack-pattern hits feed `Rack::Attack::Fail2Ban` (`attack:<ip>`, `maxretry: 3`, `bantime: 24h`). After 3 strikes in an hour the IP is added to a rack-attack `blocklist` and gets 403 on all paths for 24h.
- **Real client IP behind Cloudflare**: both the controller (`client_ip`) and rack-attack (`Rack::Attack.client_ip`) read `CF-Connecting-IP` first, falling back to `req.ip` — otherwise every visitor would look like a Cloudflare edge address and throttles/bans would be wrong.
- **CSP**: `script_src :self` (no `:https`); per-request random nonce via `SecureRandom.base64(16)`.
- **Other headers**: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection: 0` (deprecated mechanism intentionally off), strict referrer policy, restrictive `Permissions-Policy`.
- **Static export escaping**: `lib/tasks/memorial.rake` unicode-escapes `<>&` when embedding messages JSON into an inline `<script>` so `</script>` in content can't break out.
- `master.key` and `config/database.yml` are gitignored and have never been committed.

Rails is deliberately kept on the 7.2.x series (currently 7.2.3.1, still receiving security patches). Upgrading to Rails 8 is a future, separate task.

## Development Commands

Start server: `bin/rails server`
Console: `bin/rails console`
DB ops: `bin/rails db:migrate`, `bin/rails db:seed`
Assets: `bin/rails assets:precompile`
Static scanners: `bundle exec brakeman` and `bundle exec bundler-audit check --update`

### Testing

```bash
bin/rails test                            # full suite (55 runs)
bin/rails test test/models                # one directory
bin/rails test test/lib/tasks/            # the rake-task tests
```

**Test suite caveats** (non-obvious):
- MySQL must be running locally; the test DB credentials must match your local `config/database.yml` (gitignored).
- `test_helper.rb` sets `parallelize(workers: 1)` **on purpose** — the rake-task tests share on-disk dirs (`static_output/`, `backup/`) and global Rake/DB-connection state, so forked workers race and fail intermittently. Don't re-enable parallelization without first making those tests use per-process temp dirs.
- The two rake-task test classes (`MemorialRakeTest`, `MemorialClearTest`) are intentionally `use_transactional_tests = false`, because the tasks run DDL (`ALTER TABLE … AUTO_INCREMENT`) and `clear_all_connections!`, which would break transactional isolation.
- Each rake-task `setup` guards `Rails.application.load_tasks` with `unless Rake::Task.task_defined?(...)`. Without that guard, `load_tasks` would *append* another action block each call, so the task body would run N× on the Nth invoke and the clear task's `count==0 → exit` would kill the run.
- The honeypot test posts an `email_confirmation` param and expects no Message created.
- `test/integration/comment_abuse_blocking_test.rb` is the one place rack-attack is turned on; it flips `Rack::Attack.enabled` to true with a process-unique `FileStore` and restores both (plus the cache store and memorial config) in `teardown`, so it can't bleed counts into other tests or runs.

### Ruby 3.4 build note

Ruby 3.4 compiles C extensions with `-std=gnu23` (C23), which rejects mysql2's K&R-style gperf header. The required flag is committed at `.bundle/config`:

```yaml
BUNDLE_BUILD__MYSQL2: "--with-cflags=-std=gnu17"
```

`csv` is no longer a default gem in Ruby 3.4 either; it's declared in the Gemfile.

## Key Files

- `app/controllers/pages_controller.rb` — controller + honeypot/attack-pattern checks + Fail2Ban flagging
- `app/lib/security_filter.rb` — `SecurityFilter.attack_signature` injection-pattern matcher
- `app/models/message.rb` — validations + sanitize
- `app/views/pages/index.html.erb` — memorial display
- `app/views/pages/say.html.erb` — submit form (contains the honeypot div)
- `app/helpers/application_helper.rb` — `commenting_enabled?` (single source of truth; the controller calls it via `helpers.commenting_enabled?`)
- `config/routes.rb` — `root`, `/say` (GET/POST), `/health`
- `config/initializers/rack_attack.rb` — throttling config
- `config/initializers/content_security_policy.rb` — CSP + nonce
- `config/environments/production.rb` — `assume_ssl` / `force_ssl` for Cloudflare
- `lib/tasks/memorial.rake` — export / static / clear tasks
- `db/migrate/20230531164447_create_messages.rb` — schema

## Testing framework

Standard Rails Minitest + Capybara/Selenium for system tests. System tests live in `test/system/` and run separately via `bin/rails test:system`.
