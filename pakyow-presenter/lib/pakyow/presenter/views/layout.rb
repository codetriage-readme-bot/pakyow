# frozen_string_literal: true

module Pakyow
  module Presenter
    class Layout < View
      attr_accessor :name

      class << self
        def load(path, content: nil, **args)
          self.new(File.basename(path, ".*").to_sym, content || File.read(path), **args)
        end
      end

      def initialize(name, html = "", **args)
        @name = name
        super(html, **args)
      end

      # TODO: is this used?
      def container(name = Page::DEFAULT_CONTAINER)
        @object.container(name.to_sym)
      end

      def build(page)
        @delegate.each_significant_node(:container, @object) do |container_node|
          @delegate.replace_node(container_node, page.content(container_node.label(:container)))
        end

        View.from_object(@delegate, nil).add_info(info, page.info)
      end
    end
  end
end
