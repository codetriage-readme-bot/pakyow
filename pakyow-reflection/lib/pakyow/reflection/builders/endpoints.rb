# frozen_string_literal: true

require "pakyow/support/core_refinements/string/normalization"

require "pakyow/reflection/builders/abstract"
require "pakyow/reflection/extensions/controller"

module Pakyow
  module Reflection
    module Builders
      class Endpoints < Abstract
        using Support::Refinements::String::Normalization

        def initialize(*)
          @reflected_routes = []

          super
        end

        def build(scope)
          scope.actions.each do |action|
            ensure_action_for_scope(action, scope)
          end

          scope.endpoints.each do |endpoint|
            ensure_endpoint_for_scope(endpoint, scope)
          end
        end

        private

        def ensure_action_for_scope(action, scope)
          resource = find_or_define_resource_for_scope(scope)
          ensure_controller_has_helpers(resource)

          # Define the route unless it exists.
          #
          # Actions are easy since they always go in the resource controller for
          # the scope. If a nested scope, the action is defined on the nested
          # resource returned by `find_or_define_resource_for_scope`.
          #
          route = resource.routes.values.flatten.find { |possible_route|
            possible_route.name == action.name
          } || resource.send(action.name)

          # Install the reflect action if it hasn't been installed for this route.
          #
          unless @reflected_routes.include?(route)
            if route.name
              # TODO: this may become reflected_action_scope, since actions act on one scope but endpoints act on (potentially) many
              #
              resource.action :set_reflected_scope, only: [route.name] do
                connection.set(:__reflected_scope, scope)
              end

              resource.action :set_reflected_action, only: [route.name] do
                if connection.form
                  form_view_path = connection.form[:view_path]
                  form_channel = connection.form[:binding].to_s.split(":", 2)[1].to_s.split(":").map(&:to_sym)

                  connection.set(:__reflected_action, scope.actions.find { |possible_action|
                    possible_action.view_path == form_view_path && possible_action.channel == form_channel
                  })
                end
              end

              action_block = case route.name
              when :create
                call_reflective_create_action
              when :update
                call_reflective_update_action
              when :delete
                call_reflective_delete_action
              else
                # TODO: raise an error about an unknown action
              end

              resource.action :reflect, only: [route.name], &action_block
            else
              # TODO: warn the user that a reflection couldn't be installed for an unnamed route
            end

            @reflected_routes << route
          end
        end

        def ensure_controller_has_helpers(controller)
          unless controller.ancestors.include?(Extension::Controller)
            controller.include Extension::Controller
          end
        end

        def ensure_endpoint_for_scope(endpoint, scope)
          controller = find_or_define_controller_for_endpoint(endpoint)
          ensure_controller_has_helpers(controller)

          route_name, route_path = if endpoint_directory?(endpoint.view_path)
            [:default, "/"]
          else
            last_endpoint_path_part = endpoint.view_path.split("/").last
            [last_endpoint_path_part.to_sym, "/#{last_endpoint_path_part}"]
          end

          # Define the route unless it exists.
          #
          route = controller.routes.values.flatten.find { |possible_route|
            possible_route.path == route_path
          } || controller.get(route_name, route_path)

          # Install the reflect action if it hasn't been installed for this route.
          #
          unless @reflected_routes.include?(route)
            if route.name
              endpoint_path = String.normalize_path(
                File.join(controller.path_to_self, route.path)
              )

              endpoints = @scopes.flat_map(&:endpoints).select { |endpoint|
                endpoint.view_path == endpoint_path
              }

              controller.action :set_reflected_endpoints, only: [route.name] do
                connection.set(:__reflected_endpoints, endpoints)
              end

              controller.action :reflect, only: [route.name], &call_reflective_expose
            else
              # TODO: warn the user that a reflection couldn't be installed for an unnamed route
            end

            @reflected_routes << route
          end
        end

        def find_or_define_controller_for_endpoint(endpoint)
          endpoint_path = if endpoint_directory?(endpoint.view_path)
            endpoint.view_path.split("/")[1..-1]
          else
            endpoint.view_path.split("/")[1..-2]
          end

          if endpoint_path.nil? || endpoint_path.empty?
            controller_for_endpoint_path("", @app) || define_controller_for_endpoint_path("", @app)
          else
            endpoint_path.inject(@app) { |context, endpoint_path_part|
              controller_for_endpoint_path(endpoint_path_part, context) || define_controller_for_endpoint_path(endpoint_path_part, context)
            }
          end
        end

        def controller_for_endpoint_path(endpoint_path, context)
          endpoint_path = String.normalize_path(endpoint_path)

          state = if context.is_a?(Class) && context.ancestors.include?(Controller)
            context.children
          else
            context.state(:controller)
          end

          state.find { |controller|
            controller.path == endpoint_path
          }
        end

        def define_controller_for_endpoint_path(endpoint_path, context)
          controller_name = if endpoint_path.empty?
            :root
          else
            endpoint_path.to_sym
          end

          definition_method = if context.is_a?(Class) && context.ancestors.include?(Controller)
            :namespace
          else
            :controller
          end

          context.send(definition_method, controller_name, String.normalize_path(endpoint_path)) do
            # intentionally empty
          end
        end

        def endpoint_directory?(endpoint)
          @app.state(:templates).any? { |templates|
            File.directory?(File.join(templates.path, templates.config[:paths][:pages], endpoint))
          }
        end

        def find_or_define_resource_for_scope(scope)
          context = if scope.parent
            find_or_define_resource_for_scope(scope.parent)
          else
            @app
          end

          resource_for_scope(scope, context) || define_resource_for_scope(scope, context)
        end

        def resource_for_scope(scope, context)
          state = if context.is_a?(Class) && context.ancestors.include?(Controller)
            context.children
          else
            context.state(:controller)
          end

          state.select { |controller|
            controller.ancestors.include?(Routing::Extension::Resource)
          }.find { |controller|
            controller.__object_name.name == scope.plural_name
          }
        end

        def define_resource_for_scope(scope, context)
          context.resource scope.plural_name, resource_path_for_scope(scope) do
            # intentionally empty
          end
        end

        def resource_path_for_scope(scope)
          String.normalize_path(scope.plural_name)
        end

        def call_reflective_expose
          Proc.new do
            reflective_expose
          end
        end

        def call_reflective_create_action
          Proc.new do
            reflective_create
          end
        end

        def call_reflective_update_action
          Proc.new do
            reflective_update
          end
        end

        def call_reflective_delete_action
          Proc.new do
            reflective_delete
          end
        end

        # def resource_for_scope(scope, context)
        #   state = if context.is_a?(Class) && context.ancestors.include?(Controller)
        #     context.children
        #   else
        #     context.state(:controller)
        #   end

        #   state.select { |controller|
        #     controller.ancestors.include?(Routing::Extension::Resource)
        #   }.find { |controller|
        #     controller.__object_name.name == scope.plural_name
        #   }
        # end

        # def define_resource_for_scope(scope, context)
        #   context.resource scope.plural_name, resource_path_for_scope(scope) do
        #     include Extension::Controller
        #   end
        # end

        # def resource_path_for_scope(scope)
        #   String.normalize_path(scope.plural_name)
        # end

        # def needs_resource?(scope)
        #   scope.actions.any? || scope.endpoints.any? { |endpoint|
        #     endpoint_within_path?(endpoint, resource_path_for_scope(scope))
        #   }
        # end

        # def needs_controller?(scope)
        #   scope.endpoints.any? { |endpoint|
        #     !endpoint_within_path?(endpoint, resource_path_for_scope(scope))
        #   }
        # end

        # def endpoint_within_path?(endpoint, path)
        #   endpoint.view_path.start_with?(path)
        # end
      end
    end
  end
end
