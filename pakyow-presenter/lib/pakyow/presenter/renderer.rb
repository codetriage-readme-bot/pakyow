# frozen_string_literal: true

require "pakyow/support/hookable"
require "pakyow/support/core_refinements/string/normalization"

module Pakyow
  module Presenter
    module RenderHelpers
      def render(path = request.env["pakyow.endpoint"] || request.path, as: nil, layout: nil, mode: :default)
        app.class.const_get(:Renderer).new(@connection, path: path, as: as, layout: layout, mode: mode).perform
      end
    end

    class Renderer
      class << self
        def perform_for_connection(connection)
          if implicitly_render?(connection)
            begin
              catch :halt do
                new(connection, implicit: true).perform
              end
            rescue MissingPage => error
              implicit_error = ImplicitRenderingError.new("Could not implicitly render at path `#{connection.path}'")
              implicit_error.context = connection.path
              implicit_error.set_backtrace(error.backtrace)
              connection.set(:error, implicit_error)
              connection.status = 404

              catch :halt do
                if Pakyow.env?(:production)
                  connection.app.class.const_get(:Controller).new(connection).trigger(404)
                else
                  new(connection, path: "/development/500").perform
                end
              end
            end
          end
        end

        def implicitly_render?(connection)
          connection.status == 200 && connection.method == :get && connection.format == :html &&
          (Pakyow.env?(:prototype) || ((!connection.halted? || connection.set?(:__fully_dispatched)) && !connection.rendered?))
        end
      end

      include Support::Hookable
      known_events :render

      using Support::Refinements::String::Normalization

      attr_reader :connection, :presenter

      def initialize(connection, path: nil, as: nil, layout: nil, mode: :default, implicit: false, templates: true)
        @connection, @implicit = connection, implicit

        @path = String.normalize_path(path || default_path)
        @as = as ? String.normalize_path(as) : nil
        @layout = layout
        @mode = mode

        unless info = find_info(@path)
          error = MissingPage.new("No view at path `#{@path}'")
          error.context = @path
          raise error
        end

        # Finds a matching layout across template stores.
        #
        if @layout && layout_object = layout_with_name(@layout)
          info[:layout] = layout_object.dup
        end

        @automatic_presentation = false
        unless presenter_class = find_presenter(@as || @path)
          presenter_class = ViewPresenter
          @automatic_presentation = true
        end

        @presenter = presenter_class.new(
          binders: @connection.app.state_for(:binder),
          **info
        )

        @presenter.install_endpoints(
          endpoints_for_environment,
          current_endpoint: @connection.endpoint,
          setup_for_bindings: rendering_prototype?
        )

        if rendering_prototype?
          @mode = @connection.params[:mode] || :default
        end

        @presenter.place_in_mode(@mode)

        if rendering_prototype?
          @presenter.insert_prototype_bar(@mode)
        else
          @presenter.cleanup_prototype_nodes

          if templates
            @presenter.create_template_nodes
          end
        end

        if @connection.app.config.presenter.embed_authenticity_token
          embed_authenticity_token
        end

        setup_forms
      end

      def perform
        if automatic_presentation?
          find_and_present_presentables(@connection.values)
        else
          define_presentables(@connection.values)
        end

        performing :render do
          @connection.body = StringIO.new(
            @presenter.to_html(clean_bindings: !rendering_prototype?)
          )
        end

        @connection.rendered
      end

      protected

      def rendering_implicitly?
        @implicit == true
      end

      def rendering_prototype?
        Pakyow.env?(:prototype)
      end

      def automatic_presentation?
        @automatic_presentation == true
      end

      # We still mark endpoints as active when running in the prototype environment, but we don't
      # want to replace anchor hrefs, form actions, etc with backend routes. This gives the designer
      # control over how the prototype behaves.
      #
      def endpoints_for_environment
        if rendering_prototype?
          Endpoints.new
        else
          @connection.app.endpoints
        end
      end

      def default_path
        @connection.env["pakyow.endpoint"] || @connection.path
      end

      def find_info(path)
        collapse_path(path) do |collapsed_path|
          if info = info_for_path(collapsed_path)
            return info
          end
        end
      end

      def find_presenter(path)
        unless rendering_prototype?
          collapse_path(path) do |collapsed_path|
            if presenter = presenter_for_path(collapsed_path)
              return presenter
            end
          end
        end

        nil
      end

      def info_for_path(path)
        @connection.app.state_for(:templates).lazy.map { |store|
          store.info(path)
        }.find(&:itself)
      end

      def layout_with_name(name)
        @connection.app.state_for(:templates).lazy.map { |store|
          store.layout(name)
        }.find(&:itself)
      end

      def presenter_for_path(path)
        @connection.app.state_for(:presenter).find { |presenter|
          presenter.path == path
        }
      end

      def collapse_path(path)
        yield path; return if path == "/"

        yield path.split("/").keep_if { |part|
          part[0] != ":"
        }.join("/")

        nil
      end

      def define_presentables(presentables)
        presentables.each do |name, value|
          @presenter.define_singleton_method name do
            value
          end
        end
      end

      def find_and_present_presentables(presentables)
        presentables.each do |name, value|
          [name, Support.inflector.singularize(name)].each do |name_varient|
            found = @presenter.find(name_varient)
            unless found.nil?
              found.present(value); break
            end
          end
        end
      end

      include Routing::Helpers::CSRF

      def embed_authenticity_token
        if head = @presenter.view.object.find_significant_nodes(:head)[0]
          # embed the authenticity token
          head.append("<meta name=\"pw-authenticity-token\" content=\"#{authenticity_client_id}:#{authenticity_digest(authenticity_client_id)}\">\n")

          # embed the parameter name the token should be submitted as
          head.append("<meta name=\"pw-authenticity-param\" content=\"#{@connection.app.config.csrf.param}\">\n")
        end
      end

      def setup_forms
        @presenter.forms.each do |form|
          form.embed_origin(@connection.fullpath)

          if @connection.app.config.presenter.embed_authenticity_token
            digest = Support::MessageVerifier.digest(
              form.id, key: authenticity_server_id
            )

            form.embed_authenticity_token("#{form.id}:#{digest}", param: @connection.app.config.csrf.param)
          end
        end
      end
    end
  end
end
