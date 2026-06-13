# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Layout

The Rails app lives under `environment/meal-prepper/`. All commands below should be run from that directory.

- Ruby 3.4.3 (see `.ruby-version`)
- Rails 8.1 with SQLite (separate databases for development, test, production cache/queue/cable)
- Hotwire stack: Turbo + Stimulus, import maps (no Node/webpack)
- Background jobs: Solid Queue; caching: Solid Cache; WebSockets: Solid Cable

## Commands

```bash
# First-time setup
bin/setup

# Start dev server
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/foo_test.rb

# Run system tests (optional, not included in CI by default)
bin/rails test:system

# Lint
bin/rubocop

# Full CI suite (setup → lint → security → tests → seed test)
bin/ci
```

## CI Pipeline

`bin/ci` (defined in `config/ci.rb`) runs in order:
1. `bin/setup --skip-server`
2. `bin/rubocop` — Ruby style (omakase + rails + performance cops)
3. `bin/bundler-audit` — gem vulnerability check
4. `bin/importmap audit` — JS importmap vulnerability check
5. `bin/brakeman` — static security analysis
6. `bin/rails test` — unit/controller/integration tests
7. `bin/rails db:seed:replant` in test env — verifies seeds are clean

## Linting

RuboCop is configured in `.rubocop.yml` inheriting `rubocop-rails-omakase`. Additional plugins: `rubocop-rails` and `rubocop-performance`. Target Ruby 3.4. `db/schema.rb` and `bin/**/*` are excluded.

## Database

Development and test each use a single SQLite file under `storage/`. Production uses four separate SQLite files (primary, cache, queue, cable) each with their own migrations path. Run `bin/rails db:prepare` to create/migrate without dropping data.

## Docker / Deployment

The Dockerfile is production-only and uses Kamal + Thruster. For local dev use `bin/dev` directly, not Docker.
