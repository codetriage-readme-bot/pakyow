# frozen_string_literal: true

desc "Start an interactive session"
task :irb do
  Pakyow.boot

  require "#{Pakyow.config.cli.repl.to_s.downcase}"
  Pakyow.config.cli.repl.start
end
