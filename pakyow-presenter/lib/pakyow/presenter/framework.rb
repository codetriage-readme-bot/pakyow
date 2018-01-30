# frozen_string_literal: true

require "pakyow/core/framework"

module Pakyow
  module Presenter
    class Framework < Pakyow::Framework(:presenter)
      def boot
        renderer_class = subclass(Renderer)

        app.class_eval do
          action renderer_class

          stateful :templates, Templates
          stateful :presenter, ViewPresenter
          stateful :binder, Binder
          stateful :processor, Processor

          aspect :presenters
          aspect :binders

          helper RenderHelpers

          settings_for :presenter do
            setting :path do
              File.join(config.app.root, "frontend")
            end
          end

          after :load do
            self.class.templates << Templates.new(
              :default,
              config.presenter.path,
              processor: ProcessorCaller.new(
                self.class.state[:processor].instances
              )
            )

            # if environment == :development
            #   app_class.handle MissingView, as: 500 do
            #     respond_to :html do
            #       render "/missing_view"
            #     end
            #   end

            #   app_class.templates << Templates.new(:errors, File.join(File.expand_path("../../", __FILE__), "views", "errors"))

            #   # TODO: define view objects to render built-in errors
            # end

            # TODO: the following handlers override the ones defined on the app
            # ideally global handlers could coexist (e.g. handle bugsnag, then present error page)
            # perhaps by executing all of 'em at once until halted or all called; feels consistent with
            # how multiple handlers are called in non-global cases; though load order would be important

            # app_class.handle 404 do
            #   respond_to :html do
            #     render "/404"
            #   end
            # end

            # app_class.handle 500 do
            #   respond_to :html do
            #     render "/500"
            #   end
            # end
          end
        end
      end
    end
  end
end
