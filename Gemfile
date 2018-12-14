# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gemspec path: "pakyow-assets"
gemspec path: "pakyow-core"
gemspec path: "pakyow-data"
gemspec path: "pakyow-form"
gemspec path: "pakyow-presenter"
gemspec path: "pakyow-realtime"
gemspec path: "pakyow-routing"
gemspec path: "pakyow-support"
gemspec path: "pakyow-ui"

gem "htmlbeautifier", ">= 1.3"
gem "pronto", ">= 0.9"
gem "pronto-rubocop", ">= 0.9", require: false
gem "pry", ">= 0.11"
gem "pry-byebug", ">= 3.6"
gem "rubocop", ">= 0.51"

group :test do
  gem "simplecov", ">= 0.15", require: false
  gem "simplecov-console", ">= 0.4"

  gem "rack-test", ">= 0.8", require: "rack/test"

  gem "codeclimate-test-reporter", require: false

  gem "event_emitter", ">= 0.2"
  gem "httparty", ">= 0.15"
  gem "puma", ">= 3.11"

  gem "rspec", "~> 3.7"
  gem "rspec-benchmark", "~> 0.3"

  gem "warning", "~> 0.10"

  gem "babel-transpiler"
  gem "sass"

  gem "mysql2"
  gem "pg"
  gem "sqlite3"

  gem "bootsnap"
  gem "dotenv"

  gem "ruby-prof", require: false
  gem "memory_profiler", require: false
end
