# frozen_string_literal: true

module Dispatch
  module Tools
    class Error < StandardError; end

    class DuplicateToolError < Error; end

    class ToolNotFoundError < Error; end

    class ValidationError < Error; end

    class ExecutionError < Error; end
  end
end
