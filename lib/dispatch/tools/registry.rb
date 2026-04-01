# frozen_string_literal: true

module Dispatch
  module Tools
    class Registry
      def initialize
        @tools = {}
      end

      def register(tool_definition)
        name = tool_definition.name

        raise DuplicateToolError, "Tool '#{name}' is already registered" if @tools.key?(name)

        @tools[name] = tool_definition
        self
      end

      def get(name)
        @tools[name]
      end

      def fetch(name)
        @tools.fetch(name) do
          raise ToolNotFoundError, "Tool '#{name}' not found"
        end
      end

      def has?(name)
        @tools.key?(name)
      end

      def tools
        @tools.values
      end

      def tool_names
        @tools.keys
      end

      def to_a
        @tools.values.map(&:to_tool_definition)
      end

      def subset(*names)
        new_registry = self.class.new

        names.each do |name|
          new_registry.register(fetch(name))
        end

        new_registry
      end

      def size
        @tools.size
      end

      def empty?
        @tools.empty?
      end
    end
  end
end
