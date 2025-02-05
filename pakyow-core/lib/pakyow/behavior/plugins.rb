# frozen_string_literal: true

require "pakyow/errors"

require "pakyow/support/deep_dup"
require "pakyow/support/extension"

require "pakyow/plugin/lookup"
require "pakyow/plugin/helpers/parent_app"

module Pakyow
  module Behavior
    module Plugins
      extend Support::Extension

      using Support::DeepDup

      attr_reader :plugs

      apply_extension do
        class_state :__plugs, default: [], inheritable: true

        # Setting priority to low gives the app a chance to do any pre-loading
        # that might affect how plugins are setup.
        #
        before :load, priority: :low do
          # Create a dynamic helper that allows plugin helpers to be called in context of a specific plug.
          #
          dynamic_helper = Module.new {
            Pakyow.plugins.keys.map.each do |plugin_name|
              define_method plugin_name do |plug = :default|
                app.plugs.send(plugin_name, plug).helper_caller(
                  app.class.__included_helpers[self.class],
                  @connection,
                  self
                )
              end
            end
          }

          self.class.register_helper :passive, dynamic_helper

          @__plug_instances = self.class.__plugs.map { |plug|
            # Register helpers.
            #
            plug.register_helper :passive, Plugin::Helpers::ParentApp

            if self.class.includes_framework?(:presenter)
              require "pakyow/plugin/helpers/rendering"
              plug.register_helper :passive, Plugin::Helpers::Rendering
            end

            # Include frameworks from app.
            #
            plug.include_frameworks(
              *self.class.config.loaded_frameworks
            )

            # Copy config from the app.
            #
            plug.config.instance_variable_set(:@settings, config.settings.deep_dup.merge(plug.config.settings))

            # Override config values that require a specific value.
            #
            full_name = [plug.plugin_name]
            unless plug.__object_name.name == :default
              full_name << plug.__object_name.name
            end

            plug.config.name = full_name.join("_").to_sym
            plug.config.root = plug.plugin_path

            # Finally, create the plugin instance.
            #
            plug.new(self)
          }

          @plugs = Plugin::Lookup.new(@__plug_instances)
        end
      end

      class_methods do
        attr_reader :__plugs

        def plug(plugin_name, at: "/", as: :default, &block)
          plugin_name = plugin_name.to_sym

          unless plugin = Pakyow.plugins[plugin_name]
            raise UnknownPlugin.new_with_message(
              plugin: plugin_name
            )
          end

          plug = plugin.make(
            as,
            within: Support::ObjectNamespace.new(
              *__object_name.namespace.parts + [plugin_name]
            ),
            mount_path: at,
            &block
          )

          @__plugs << plug
        end
      end
    end
  end
end
