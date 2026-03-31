# frozen_string_literal: true

module Dispatch
  module Tools
    class Result
      attr_reader :output, :error, :metadata

      def self.success(output:, metadata: {})
        new(success: true, output:, error: nil, metadata:)
      end

      def self.failure(error:, metadata: {})
        new(success: false, output: nil, error:, metadata:)
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def to_s
        success? ? output : error
      end

      def to_h
        {
          success: @success,
          output:,
          error:,
          metadata:
        }
      end

      private

      def initialize(success:, output:, error:, metadata:)
        @success = success
        @output = output
        @error = error
        @metadata = metadata
        freeze
      end
    end
  end
end
