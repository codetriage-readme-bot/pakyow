# frozen_string_literal: true

require "pakyow/support/extension"

module Pakyow
  module Presenter
    module Actions
      module CleanupPrototypeNodes
        extend Support::Extension

        apply_extension do
          build do |app, view|
            unless Pakyow.env?(:prototype)
              view.object.each_significant_node(:prototype).map(&:itself).each(&:remove)
            end
          end
        end
      end
    end
  end
end
