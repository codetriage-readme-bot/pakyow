# frozen_string_literal: true

require "pakyow/support/aargv"
require "pakyow/support/array"

require "pakyow/support/makeable"

require "pakyow/support/pipelined"

require "pakyow/core/call_helpers"
require "pakyow/core/routing/helpers"
require "pakyow/core/routing/behavior/error_handling"

module Pakyow
  # Executes code for particular requests. For example:
  #
  #   Pakyow::App.controller do
  #     get "/" do
  #       # called for GET / requests
  #     end
  #   end
  #
  # A +Class+ is created dynamically for each defined controller. When matched, a route is called in
  # context of its controller. This means that any method defined in a controller is available to be
  # called from within a route. For example:
  #
  #   Pakyow::App.controller do
  #     def foo
  #     end
  #
  #     get :foo, "/foo" do
  #       foo
  #     end
  #   end
  #
  # Including modules works as expected:
  #
  #   module AuthHelpers
  #     def current_user
  #     end
  #   end
  #
  #   Pakyow::App.controller do
  #     include AuthHelpers
  #
  #     get :foo, "/foo" do
  #       current_user
  #     end
  #   end
  #
  # See {App.controller} for more details on defining controllers.
  #
  # = Supported HTTP methods
  #
  # - +GET+
  # - +POST+
  # - +PUT+
  # - +PATCH+
  # - +DELETE+
  #
  # See {get}, {post}, {put}, {patch}, and {delete}.
  #
  # +HEAD+ requests are handled automatically via {Rack::Head}.
  #
  # = Building paths for named routes
  #
  # Path building is supported via {Controller#path} and {Controller#path_to}.
  #
  # = Reusing logic with actions
  #
  # Methods can be defined as additional actions for a route. For example:
  #
  #   Pakyow::App.controller do
  #     action :called_before
  #
  #     def called_before
  #       ...
  #     end
  #
  #     get :foo, "/foo" do
  #       ...
  #     end
  #   end
  #
  # = Extending controllers
  #
  # Extensions can be defined and used to add shared routes to one or more controllers.
  # See {Routing::Extension}.
  #
  # = Other routing features
  #
  # More advanced route features are available, including groups, namespaces, and templates. See
  # {group}, {namespace}, and {template}.
  #
  # = Controller subclasses
  #
  # It's possible to work with controllers outside of Pakyow's DSL. For example:
  #
  #   class FooController < Pakyow::Controller("/foo")
  #     default do
  #       # available at GET /foo
  #     end
  #   end
  #
  #   Pakyow::App.controller << FooController
  #
  # = Custom matchers
  #
  # Controllers and routes can be defined with a matcher rather than a path. The matcher could be a
  # +Regexp+ or any custom object that implements +match?+. For example:
  #
  #   class CustomMatcher
  #     def match?(path)
  #       path == "/custom"
  #     end
  #   end
  #
  #   Pakyow::App.controller CustomMatcher.new do
  #   end
  #
  # Custom matchers can also make data available in +params+ by implementing +match+ and returning
  # an object that implements +named_captures+. For example:
  #
  #   class CustomMatcher
  #     def match?(path)
  #       path == "/custom"
  #     end
  #
  #     def match(path)
  #       return self if match?(path)
  #     end
  #
  #     def named_captures
  #       { foo: "bar" }
  #     end
  #   end
  #
  #   Pakyow::App.controller CustomMatcher.new do
  #   end
  #
  class Controller
    include CallHelpers

    using Support::DeepDup
    extend Support::Makeable
    include Support::Hookable

    include Routing::Behavior::ErrorHandling

    include Support::Pipelined

    controller = self
    Pakyow.singleton_class.class_eval do
      define_method :Controller do |path|
        controller.Controller(path)
      end
    end

    METHOD_GET    = :get
    METHOD_POST   = :post
    METHOD_PUT    = :put
    METHOD_PATCH  = :patch
    METHOD_DELETE = :delete

    SUPPORTED_HTTP_METHODS = [
      METHOD_GET,
      METHOD_POST,
      METHOD_PUT,
      METHOD_PATCH,
      METHOD_DELETE
    ].freeze

    CONTENT_DISPOSITION = "Content-Disposition".freeze

    # @api private
    def initialize(state)
      @__state = state
    end

    def call_route(route)
      route.call(@__state, self)
      @__state.processed
    rescue StandardError => error
      handle_error(error)

      # If this controller handled the error, it would have halted the request so there's no need to
      # reraise for the application to attempt to handle it. On the other hand, if this controller
      # didn't handle the error the application needs to know that it occured.
      unless @__state.halted?
        raise error
      end
    end

    # Redirects to +location+ and immediately halts request processing.
    #
    # @param location [String] what url the request should be redirected to
    # @param as [Integer, Symbol] the status to redirect with
    #
    # @example Redirecting:
    #   Pakyow::App.controller do
    #     default do
    #       redirect "/foo"
    #     end
    #   end
    #
    # @example Redirecting with a status code:
    #   Pakyow::App.controller do
    #     default do
    #       redirect "/foo", as: 301
    #     end
    #   end
    #
    def redirect(location, as: 302, **params)
      response.status = Rack::Utils.status_code(as)
      response["Location"] = location.is_a?(Symbol) ? app.paths.path(location, **params) : location
      halt
    end

    # Reroutes the request to a different location. Instead of an http redirect, the request will
    # continued to be handled in the current request lifecycle.
    #
    # @param location [String] what url the request should be rerouted to
    # @param method [Symbol] the http method to reroute as
    #
    # @example
    #   Pakyow::App.resource :post, "/posts" do
    #     edit do
    #       @post ||= find_post_by_id(params[:post_id])
    #
    #       # render the form for @post
    #     end
    #
    #     update do
    #       if post_fails_to_create
    #         @post = failed_post_object
    #         reroute path(:post_edit, post_id: @post.id), method: :get
    #       end
    #     end
    #   end
    #
    def reroute(location, method: request.method, **params)
      request.env[Rack::REQUEST_METHOD] = method.to_s.upcase
      request.env[Rack::PATH_INFO] = location.is_a?(Symbol) ? app.paths.path(location, **params) : location
      Routing::Router.call(@__state)
    end

    # Responds to a specific request format.
    #
    # The +Content-Type+ header will be set on the response based on the format that is being
    # responded to.
    #
    # After yielding, request processing will be halted.
    #
    # @example
    #   Pakyow::App.controller do
    #     get "/foo.txt|html" do
    #       respond_to :txt do
    #         send "foo"
    #       end
    #
    #       # do something for html format
    #     end
    #   end
    #
    def respond_to(format)
      return unless request.format == format.to_sym
      response.format = format
      yield
      halt
    end

    DEFAULT_SEND_TYPE = "application/octet-stream".freeze

    # Sends a file or other data in the response.
    #
    # Accepts data as a +String+ or +IO+ object. When passed a +File+ object, the mime type will be
    # determined automatically. The type can be set explicitly with the +type+ option.
    #
    # Passing +name+ sets the +Content-Disposition+ header to "attachment". Otherwise, the
    # disposition will be set to "inline".
    #
    # @example Sending data:
    #   Pakyow::App.controller do
    #     default do
    #       send "foo", type: "text/plain"
    #     end
    #   end
    #
    # @example Sending a file:
    #   Pakyow::App.controller do
    #     default do
    #       filename = "foo.txt"
    #       send File.open(filename), name: filename
    #     end
    #   end
    #
    def send(file_or_data, type: nil, name: nil)
      if file_or_data.is_a?(IO) || file_or_data.is_a?(StringIO)
        data = file_or_data

        if file_or_data.is_a?(File)
          type ||= Rack::Mime.mime_type(File.extname(file_or_data.path))
        end

        response[Rack::CONTENT_TYPE] = type || DEFAULT_SEND_TYPE
      elsif file_or_data.is_a?(String)
        response[Rack::CONTENT_TYPE] = type if type
        data = StringIO.new(file_or_data)
      else
        raise ArgumentError, "Expected an IO or String object"
      end

      response[CONTENT_DISPOSITION] = name ? "attachment; filename=#{name}" : "inline"
      halt(data)
    end

    # Halts request processing, immediately returning the response.
    #
    # The response body will be set to +body+ prior to halting (if it's a non-nil value).
    #
    def halt(body = nil)
      response.body = body if body
      @__state.halt
      throw :halt
    end

    # Rejects the request, calling the next matching route.
    #
    def reject
      throw :reject
    end

    extend Support::ClassLevelState
    class_level_state :children, default: [], inheritable: true
    class_level_state :templates, default: {}, inheritable: true
    class_level_state :handlers, default: {}, inheritable: true
    class_level_state :exceptions, default: {}, inheritable: true
    class_level_state :routes, default: SUPPORTED_HTTP_METHODS.each_with_object({}) { |supported_method, routes_hash|
                                          routes_hash[supported_method] = []
                                        }, inheritable: true

    class_level_state :route_actions, default: {}, inheritable: true
    class_level_state :route_skips, default: {}, inheritable: true

    class << self
      def action(name, only: [], skip: [])
        only.each do |route_name|
          (@route_actions[route_name] ||= []) << name
        end

        skip.each do |route_name|
          (@route_skips[route_name] ||= []) << name
        end

        if only.empty?
          pipeline.include_actions([name])
        end
      end

      def skip_action(name, only: [])
        only.each do |route_name|
          (@route_skips[route_name] ||= []) << name
        end

        if only.empty?
          pipeline.exclude_actions([name])
        end
      end

      def use_pipeline(pipeline_module)
        pipeline.clear
        include_pipeline(pipeline_module)
      end

      def include_pipeline(pipeline_module)
        include pipeline_module
      end

      def exclude_pipeline(pipeline_module)
        pipeline.exclude(pipeline_module)
      end

      def handle_missing(state)
        new(state).trigger(404)
      end

      def handle_failure(state, error)
        controller = new(state)
        # try to handle the specific error
        controller.handle_error(error)
        # otherwise, just handle as a generic 500
        controller.trigger(500)
      end

      # Conveniently define defaults when subclassing +Pakyow::Controller+.
      #
      # @example
      #   class MyController < Pakyow::Controller("/foo")
      #     # more routes here
      #   end
      #
      # rubocop:disable Naming/MethodName
      def Controller(matcher)
        make(matcher)
      end
      # rubocop:enabled Naming/MethodName

      # Create a default route. Shorthand for +get "/"+.
      #
      # @see get
      #
      def default(&block)
        get :default, "/", &block
      end

      # @!method get
      #   Create a route that matches +GET+ requests at +path+. For example:
      #
      #     Pakyow::App.controller do
      #       get "/foo" do
      #         # do something
      #       end
      #     end
      #
      #   Routes can be named, making them available for path building via {Controller#path}. For
      #   example:
      #
      #     Pakyow::App.controller do
      #       get :foo, "/foo" do
      #         # do something
      #       end
      #     end
      #
      # @!method post
      #   Create a route that matches +POST+ requests at +path+.
      #
      #   @see get
      #
      # @!method put
      #   Create a route that matches +PUT+ requests at +path+.
      #
      #   @see get
      #
      # @!method patch
      #   Create a route that matches +PATCH+ requests at +path+.
      #
      #   @see get
      #
      # @!method delete
      #   Create a route that matches +DELETE+ requests at +path+.
      #
      #   @see get
      #
      SUPPORTED_HTTP_METHODS.each do |http_method|
        define_method http_method.downcase.to_sym do |name_or_matcher = nil, matcher_or_name = nil, &block|
          build_route(http_method, name_or_matcher, matcher_or_name, &block)
        end
      end

      # Creates a nested group of routes, with an optional name.
      #
      # Named groups make the routes available for path building. Paths to routes defined in unnamed
      # groups are referenced by the most direct parent group that is named.
      #
      # @example Defining a group:
      #   Pakyow::App.controller do
      #
      #     def foo
      #       logger.info "foo"
      #     end
      #
      #     group :foo do
      #       action :foo
      #       action :bar
      #
      #       def bar
      #         logger.info "bar"
      #       end
      #
      #       get :bar, "/bar" do
      #         # "foo" and "bar" have both been logged
      #         send "foo.bar"
      #       end
      #     end
      #
      #     group do
      #       action :foo
      #
      #       get :baz, "/baz" do
      #         # "foo" has been logged
      #         send "baz"
      #       end
      #     end
      #   end
      #
      # @example Building a path to a route within a named group:
      #   path :foo_bar
      #   # => "/foo/bar"
      #
      # @example Building a path to a route within an unnamed group:
      #   path :foo_baz
      #   # => nil
      #
      #   path :baz
      #   # => "/baz"
      #
      def group(name = nil, &block)
        make_child(name, nil, &block)
      end

      # Creates a group of routes and mounts them at a path, with an optional name. A namespace
      # behaves just like a group with regard to path lookup and action inheritance.
      #
      # @example Defining a namespace:
      #   Pakyow::App.controller do
      #     namespace :api, "/api" do
      #       def auth
      #         handle 401 unless authed?
      #       end
      #
      #       namespace :project, "/projects" do
      #         get :list, "/" do
      #           # route is accessible via 'GET /api/projects'
      #           send projects.to_json
      #         end
      #       end
      #     end
      #   end
      #
      def namespace(*args, &block)
        name, matcher = parse_name_and_matcher_from_args(*args)
        make_child(name, matcher, &block)
      end

      # Creates a route template with a name and block. The block is evaluated within a
      # {Routing::Expansion} instance when / if it is later expanded at some endpoint (creating a
      # namespace).
      #
      # Route templates are used to define a scaffold of default routes that will later be expanded
      # at some path. During expansion, the scaffolded routes are also mapped to routing logic.
      #
      # Because routes can be referenced by name during expansion, route templates provide a way to
      # create a domain-specific-language, or DSL, around a routing concern. This is used within
      # Pakyow itself to define the resource template ({Routing::Extension::Resource}).
      #
      # @example Defining a template:
      #   Pakyow::App.controller do
      #     template :talkback do
      #       get :hello, "/hello"
      #       get :goodbye, "/goodbye"
      #     end
      #   end
      #
      # @example Expanding a template:
      #
      #   Pakyow::App.controller do
      #     talkback :en, "/en" do
      #       hello do
      #         send "hello"
      #       end
      #
      #       goodbye do
      #         send "goodbye"
      #       end
      #
      #       # we can also extend the expansion
      #       # for our particular use-case
      #       get "/thanks" do
      #         send "thanks"
      #       end
      #     end
      #
      #     talkback :fr, "/fr" do
      #       hello do
      #         send "bonjour"
      #       end
      #
      #       # `goodbye` will not be an endpoint
      #       # since we did not expand it here
      #     end
      #   end
      #
      def template(name, &template_block)
        templates[name] = template_block
      end

      # Expands a defined route template, or raises +NameError+.
      #
      # @see template
      #
      def expand(name, *args, &block)
        make_child(*args).expand_within(name, &block)
      end

      # Attempts to find and expand a template, avoiding the need to call {expand} explicitly. For
      # example, these calls are identical:
      #
      #   Pakyow::App.controller do
      #     resource :post, "/posts" do
      #     end
      #
      #     expand :resource, :post, "/posts" do
      #     end
      #   end
      #
      def method_missing(name, *args, &block)
        if templates.include?(name)
          expand(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        templates.include?(method_name) || super
      end

      # @api private
      attr_reader :path, :matcher

      # @api private
      attr_accessor :parent

      def path_to_self
        return path unless parent
        File.join(parent.path_to_self.to_s, path.to_s)
      end

      # @api private
      def path_to(*names, **params)
        # look for a matching route before descending into child controllers
        combined_name = names.join("_").to_sym
        if found_route = routes.values.flatten.find { |route| route.name == combined_name }
          return found_route.populated_path(path_to_self, **params)
        end

        first_name = names.first
        matched_controllers = children.reject { |controller_to_match|
          controller_to_match&.__class_name&.name != first_name
        }

        matched_controllers.each do |matched_controller|
          if path = matched_controller.path_to(*names[1..-1], **params)
            return path
          end
        end

        nil
      end

      def make(*args, **kwargs, &block)
        name, matcher = parse_name_and_matcher_from_args(*args)

        path = path_from_matcher(matcher)
        matcher = finalize_matcher(matcher || "/")

        super(name, path: path, matcher: matcher, **kwargs, &block)
      end

      # @api private
      def make_child(*args, **kwargs, &block)
        name, matcher = parse_name_and_matcher_from_args(*args)
        name = __class_name.subclass(name) if name && name.is_a?(Symbol) && __class_name

        controller = make(name, matcher, parent: self, **kwargs, &block)
        children << controller
        controller
      end

      # @api private
      def try_routing(state, request_path = state.request.path)
        request_method = state.request.method

        if match = matcher.match(request_path)
          match_data = match.named_captures

          if matcher.is_a?(Regexp)
            request_path = String.normalize_path(request_path.sub(matcher, ""))
          end

          routes[request_method].each do |route|
            catch :reject do
              if route_match = route.match(request_path)
                match_data.merge!(route_match.named_captures)

                state.request.params.merge!(match_data)
                state.request.env["pakyow.endpoint"] = File.join(path_to_self.to_s, route.path.to_s)

                self.new(state).call_route(route)
              end
            end

            break if state.processed?
          end

          children.each do |child_controller|
            child_controller.try_routing(state, request_path)
          end
        end
      end

      # @api private
      def merge(controller)
        merge_pipeline(controller.pipeline)
        merge_routes(controller.routes)
        merge_templates(controller.templates)
      end

      # @api private
      def expand_within(name, &block)
        raise NameError, "Unknown template `#{name}'" unless template = templates[name]
        Routing::Expansion.new(name, self, &template)
        class_eval(&block)
      end

      protected

      def parse_name_and_matcher_from_args(name_or_matcher = nil, matcher_or_name = nil)
        Aargv.normalize([name_or_matcher, matcher_or_name].compact, name: [Symbol, Support::ClassName], matcher: Object).values_at(:name, :matcher)
      end

      def finalize_matcher(matcher)
        if matcher.is_a?(String)
          converted_matcher = String.normalize_path(matcher.split("/").map { |segment|
            if segment.include?(":")
              "(?<#{segment[1..-1]}>(\\w|[-.~:@!$\\'\\(\\)\\*\\+,;])*)"
            else
              segment
            end
          }.join("/"))

          Regexp.new("^#{String.normalize_path(converted_matcher)}")
        else
          matcher
        end
      end

      def path_from_matcher(matcher)
        if matcher.is_a?(String)
          matcher
        else
          nil
        end
      end

      def build_route(method, *args, &block)
        name, matcher = parse_name_and_matcher_from_args(*args)
        pipeline = build_pipeline_for_route(name, &block)

        Routing::Route.new(
          matcher,
          name: name,
          method: method,
          pipeline: pipeline
        ).tap do |route|
          routes[method] << route
        end
      end

      def merge_pipeline(pipeline_to_merge)
        pipeline.merge(pipeline_to_merge)
      end

      def merge_routes(routes_to_merge)
        routes.each_pair do |type, routes_of_type|
          routes_of_type.concat(routes_to_merge[type].map(&:dup))
        end
      end

      def merge_templates(templates_to_merge)
        templates.merge!(templates_to_merge)
      end

      def build_pipeline_for_route(route_name, &block)
        pipeline.dup.tap do |route_pipeline|
          route_pipeline.include_actions(@route_actions[route_name].to_a)
          route_pipeline.exclude_actions(@route_skips[route_name].to_a)
          route_pipeline.action(block) if block_given?
        end
      end
    end
  end
end
