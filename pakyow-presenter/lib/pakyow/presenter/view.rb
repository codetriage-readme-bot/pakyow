# frozen_string_literal: true

require "forwardable"

require "pakyow/support/core_refinements/array/ensurable"
require "pakyow/support/indifferentize"
require "pakyow/support/safe_string"

require "string_doc"

module Pakyow
  module Presenter
    # Provides an interface for manipulating view templates.
    #
    class View
      class << self
        # Creates a view from a file.
        #
        def load(path, content: nil)
          new(content || File.read(path))
        end

        # Creates a view wrapping an object.
        #
        def from_object(object)
          allocate.tap do |instance|
            instance.instance_variable_set(:@object, object)

            instance.instance_variable_set(:@info, {})
            instance.instance_variable_set(:@logical_path, nil)
            if object.respond_to?(:attributes)
              instance.attributes = object.attributes
            else
              instance.instance_variable_set(:@attributes, nil)
            end
          end
        end
      end

      include Support::SafeStringHelpers

      using Support::Indifferentize
      using Support::Refinements::Array::Ensurable

      extend Forwardable

      def_delegators :@object, :type, :text, :html, :label, :labeled?

      # The object responsible for parsing, manipulating, and rendering
      # the underlying HTML document for the view.
      #
      attr_reader :object

      # The logical path to the view template.
      #
      attr_reader :logical_path

      # Creates a view with +html+.
      #
      def initialize(html, info: {}, logical_path: nil)
        @object = StringDoc.new(html)
        @info, @logical_path = info, logical_path

        if @object.respond_to?(:attributes)
          self.attributes = @object.attributes
        else
          @attributes = nil
        end
      end

      def initialize_copy(_)
        super

        @info = @info.dup
        @object = @object.dup

        if @object.respond_to?(:attributes)
          self.attributes = @object.attributes
        else
          @attributes = nil
        end
      end

      # Finds a view binding by name. When passed more than one value, the view will
      # be traversed through each name. Returns a {VersionedView}.
      #
      def find(*names, channel: nil)
        if names.any?
          named = names.shift.to_sym
          combined_channel = Array.ensure(channel).join(":")

          found = each_binding(named).each_with_object([]) do |node, acc|
            if !channel || node.label(:combined_channel) == combined_channel || node.label(:combined_channel).end_with?(":" + combined_channel)
              acc << View.from_object(node)
            end
          end

          result = if names.empty? && !found.empty? # found everything; wrap it up
            VersionedView.new(found)
          elsif names.count > 0 # descend further
            found.first.find(*names, channel: channel)
          else
            nil
          end

          if result && block_given?
            yield result
          end

          result
        else
          nil
        end
      end

      # Finds all view bindings by name, returning an array of {View} objects.
      #
      def find_all(named)
        each_binding(named).map { |node|
          View.from_object(node)
        }
      end

      # Finds a form with a binding matching +name+.
      #
      def form(name)
        @object.each_significant_node(:form) do |form_node|
          return Form.from_object(form_node) if form_node.label(:binding) == name
        end

        nil
      end

      # Returns all forms.
      #
      def forms
        @object.each_significant_node(:form).map { |node|
          Form.from_object(node)
        }
      end

      # Returns all components.
      #
      def components
        @object.each_significant_node_without_descending(:component).map { |node|
          View.from_object(node)
        }
      end

      # Returns all view info when +key+ is +nil+, otherwise returns the value for +key+.
      #
      def info(key = nil)
        if key.nil?
          @info
        else
          @info.fetch(key.to_s, nil)
        end
      end

      # Returns a view for the +<head>+ node.
      #
      def head
        if head_node = @object.find_first_significant_node(:head)
          View.from_object(head_node)
        else
          nil
        end
      end

      # Returns a view for the +<body>+ node.
      #
      def body
        if body_node = @object.find_first_significant_node(:body)
          View.from_object(body_node)
        else
          nil
        end
      end

      # Returns a view for the +<title>+ node.
      #
      def title
        if title_node = @object.find_first_significant_node(:title)
          View.from_object(title_node)
        else
          nil
        end
      end

      # Yields +self+.
      #
      def with
        tap do
          yield self
        end
      end

      # Transforms +self+ to match structure of +object+.
      #
      def transform(object)
        tap do
          if object.nil? || (object.respond_to?(:empty?) && object.empty?)
            remove
          else
            removals = []
            each_binding_prop(descend: false) do |binding|
              binding_name = if binding.significant?(:multipart_binding)
                binding.label(:binding_prop)
              else
                binding.label(:binding)
              end

              unless object.present?(binding_name)
                removals << binding
              end
            end

            removals.each(&:remove)
          end

          yield self, object if block_given?
        end
      end

      # Binds a single object.
      #
      def bind(object)
        tap do
          unless object.nil?
            each_binding_prop do |binding|
              binding_name = if binding.significant?(:multipart_binding)
                binding.label(:binding_prop)
              else
                binding.label(:binding)
              end

              if object.include?(binding_name)
                value = if object.is_a?(Binder)
                  object.__content(binding_name, binding)
                else
                  object[binding_name]
                end

                bind_value_to_node(value, binding)
                binding.set_label(:used, true)
              end
            end

            attributes[:"data-id"] = object[:id]
            self.object.set_label(:used, true)
          end
        end
      end

      # Appends a view or string to +self+.
      #
      def append(view_or_string)
        tap do
          @object.append(view_from_view_or_string(view_or_string).object)
        end
      end

      # Prepends a view or string to +self+.
      #
      def prepend(view_or_string)
        tap do
          @object.prepend(view_from_view_or_string(view_or_string).object)
        end
      end

      # Inserts a view or string after +self+.
      #
      def after(view_or_string)
        tap do
          @object.after(view_from_view_or_string(view_or_string).object)
        end
      end

      # Inserts a view or string before +self+.
      #
      def before(view_or_string)
        tap do
          @object.before(view_from_view_or_string(view_or_string).object)
        end
      end

      # Replaces +self+ with a view or string.
      #
      def replace(view_or_string)
        tap do
          @object.replace(view_from_view_or_string(view_or_string).object)
        end
      end

      # Removes +self+.
      #
      def remove
        tap do
          @object.remove
        end
      end

      # Removes +self+'s children.
      #
      def clear
        tap do
          @object.clear
        end
      end

      # Safely sets the html value of +self+.
      #
      def html=(html)
        @object.html = ensure_html_safety(html.to_s)
      end

      # Returns true if +self+ is a binding.
      #
      def binding?
        @object.significant?(:binding)
      end

      # Returns true if +self+ is a container.
      #
      def container?
        @object.significant?(:container)
      end

      # Returns true if +self+ is a partial.
      #
      def partial?
        @object.significant?(:partial)
      end

      # Returns true if +self+ is a form.
      #
      def form?
        @object.significant?(:form)
      end

      # Returns true if +self+ equals +other+.
      #
      def ==(other)
        other.is_a?(self.class) && @object == other.object
      end

      # Returns attributes object for +self+.
      #
      def attributes
        @attributes
      end
      alias attrs attributes

      # Wraps +attributes+ in a {Attributes} instance.
      #
      def attributes=(attributes)
        @attributes = Attributes.new(attributes)
      end
      alias attrs= attributes=

      # Returns the version name for +self+.
      #
      def version
        (label(:version) || VersionedView::DEFAULT_VERSION).to_sym
      end

      # Converts +self+ to html, rendering the view.
      #
      def to_html(clean_bindings: true, clean_versions: true)
        if clean_bindings
          remove_unused_bindings
        end

        if clean_versions
          remove_unused_versions
        end

        @object.to_html
      end
      alias :to_s :to_html

      # @api private
      def binding_name
        label(:binding)
      end

      # @api private
      def channeled_binding_name
        [label(:binding)].concat(label(:channel)).join(":")
      end

      # @api private
      def each_binding_scope(descend: true)
        return enum_for(:each_binding_scope, descend: descend) unless block_given?

        method = if descend
          :each_significant_node
        else
          :each_significant_node_without_descending
        end

        @object.send(method, :binding) do |node|
          if binding_scope?(node)
            yield node
          end
        end
      end

      # @api private
      def each_binding_prop(descend: true)
        return enum_for(:each_binding_prop, descend: descend) unless block_given?

        if @object.is_a?(StringDoc::Node) && @object.significant?(:multipart_binding)
          yield @object
        else
          method = if descend
            :each_significant_node
          else
            :each_significant_node_without_descending
          end

          @object.send(method, :binding) do |node|
            if binding_prop?(node)
              yield node
            end
          end
        end
      end

      # @api private
      def each_binding(name)
        return enum_for(:each_binding, name) unless block_given?

        each_binding_scope do |node|
          yield node if node.label(:binding) == name
        end

        each_binding_prop do |node|
          yield node if node.label(:binding) == name
        end
      end

      # @api private
      def binding_scopes(descend: true)
        each_binding_scope(descend: descend).map(&:itself)
      end

      # @api private
      def binding_props(descend: true)
        each_binding_prop(descend: descend).map(&:itself)
      end

      # @api private
      def binding_scope?(node)
        node.significant?(:binding) && (node.significant?(:binding_within) || node.significant?(:multipart_binding) || node.label(:version) == :empty)
      end

      # @api private
      def binding_prop?(node)
        node.significant?(:binding) && (!node.significant?(:binding_within) || node.significant?(:multipart_binding))
      end

      # @api private
      def find_partials(partials, found = [])
        found.tap do
          @object.each_significant_node(:partial) do |node|
            if replacement = partials[node.label(:partial)]
              found << node.label(:partial)
              replacement.find_partials(partials, found)
            end
          end
        end
      end

      # @api private
      def mixin(partials)
        tap do
          @object.each_significant_node(:partial) do |partial_node|
            if replacement = partials[partial_node.label(:partial)]
              partial_node.replace(replacement.mixin(partials).object)
            end
          end
        end
      end

      # Thanks Dan! https://stackoverflow.com/a/30225093
      # @api private
      INFO_MERGER = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }

      # @api private
      def add_info(*infos)
        tap do
          infos.each do |info|
            @info.merge!(info, &INFO_MERGER)
          end
        end
      end

      protected

      def bind_value_to_node(value, node)
        tag = node.tagname
        unless StringDoc::Node.without_value?(tag)
          value = String(value)

          if StringDoc::Node.self_closing?(tag)
            node.attributes[:value] = ensure_html_safety(value) if node.attributes[:value].nil?
          else
            node.html = ensure_html_safety(value)
          end
        end
      end

      def remove_unused_bindings
        @object.each_significant_node(:binding).select { |node|
          !node.labeled?(:used)
        }.each(&:remove)
      end

      def remove_unused_versions
        @object.each.select { |node|
          (node.is_a?(StringDoc::Node) && node.significant? && node.labeled?(:version)) && node.label(:version) != VersionedView::DEFAULT_VERSION
        }.each(&:remove)
      end

      def view_from_view_or_string(view_or_string)
        if view_or_string.is_a?(View)
          view_or_string
        elsif view_or_string.is_a?(String)
          View.new(ensure_html_safety(view_or_string))
        else
          View.new(ensure_html_safety(view_or_string.to_s))
        end
      end
    end
  end
end
