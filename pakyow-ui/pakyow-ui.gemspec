# frozen_string_literal: true

require File.expand_path("../../lib/pakyow/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name        = "pakyow-ui"
  spec.version     = Pakyow::VERSION
  spec.summary     = "Pakyow UI"
  spec.description = "Auto-Updating UIs for Pakyow"

  spec.author   = "Bryan Powell"
  spec.email    = "bryan@metabahn.com"
  spec.homepage = "https://pakyow.org"

  spec.required_ruby_version = ">= 2.5.0"

  spec.license = "LGPL-3.0"

  spec.files        = Dir["CHANGELOG.md", "README.md", "LICENSE", "lib/**/*"]
  spec.require_path = "lib"

  spec.add_dependency "pakyow-core", Pakyow::VERSION
  spec.add_dependency "pakyow-data", Pakyow::VERSION
  spec.add_dependency "pakyow-presenter", Pakyow::VERSION
  spec.add_dependency "pakyow-realtime", Pakyow::VERSION
  spec.add_dependency "pakyow-routing", Pakyow::VERSION
  spec.add_dependency "pakyow-support", Pakyow::VERSION
end
