# frozen_string_literal: true

require "json_schemer"

module Dispatch
  module Tools
    class Definition
      attr_reader :name, :description, :parameters

      def initialize(name:, description:, parameters:, &block)
        @name = name
        @description = description
        @parameters = parameters
        @block = block
        @schemer = JSONSchemer.schema(deep_stringify_keys(parameters))
      end

      def call(params, context: {})
        symbolized = symbolize_keys(params)
        valid, errors = validate_params(params)

        return Result.failure(error: "Parameter validation failed: #{errors.join("; ")}") unless valid

        begin
          @block.call(symbolized, context)
        rescue Exception => e # rubocop:disable Lint/RescueException
          Result.failure(error: "#{e.class}: #{e.message}")
        end
      end

      def to_h
        { name:, description:, parameters: }
      end

      def to_tool_definition
        to_h
      end

      def validate_params(params)
        stringified = deep_stringify_keys(params)
        errors = @schemer.validate(stringified).map { |err| err["error"] || err.fetch("type", "unknown error") }

        if errors.empty?
          [ true, [] ]
        else
          [ false, errors ]
        end
      end

      private

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = value
        end
      end

      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_s] = deep_stringify_keys(value)
          end
        when Array
          obj.map { |item| deep_stringify_keys(item) }
        else
          obj
        end
      end
    end
  end
end
