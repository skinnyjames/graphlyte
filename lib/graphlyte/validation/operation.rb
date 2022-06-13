# frozen_string_literal: true

require_relative './field'

module Graphlyte
  module Validation
    Operations = Struct.new(:schema, :operations) do
      include Enumerable

      def validate(errors)
        validate_duplicates_and_mixes(errors)

        each { |op| op.validate(errors) }
      end

      def each
        operations.each do |op|
          yield Operation.new(schema, op)
        end
      end

      def validate_duplicates_and_mixes(errors)
        errors.concat(duplicates.map { |name| "ambiguous operation name #{name}" })
        errors << 'cannot mix anonymous and named operations' if has_anonymous_and_named?
      end

      def groups
        operations.each_with_object({}) do |operation, memo|
          memo[operation.name] = (memo[operation.name] || 0) + 1
        end
      end

      def anonymous_and_named?
        groups.keys.size > 1 && groups.keys.include?(nil)
      end

      def duplicates
        groups
          .reject { |k, _v| k.nil? }
          .select { |_k, v| v > 1 }.keys
      end
    end

    Operation = Struct.new(:schema, :operation) do
      using Refinements::StringRefinement

      def validate(errors)
        Fields.new(schema, operation).validate(errors)
      end

      # @return [Boolean] is operation anonymous?
      def anonymous?
        operation.name.nil?
      end
    end
  end
end
