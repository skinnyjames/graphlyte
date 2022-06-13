# frozen_string_literal: true

require_relative './field'

module Graphlyte
  module Validation
    Operations = Struct.new(:schema, :operations) do
      include Enumerable

      def validate(errors)
        validate_duplicates(errors)

        each { |op| op.validate(errors) }
      end

      def each
        operations.each do |op|
          yield Operation.new(schema, op)
        end
      end

      def validate_duplicates(errors)
        errors.concat(duplicates.map { |name| "ambiguous operation name #{name}" })
      end

      def duplicates
        groups = operations.each_with_object({}) do |operation, memo|
          memo[operation.name] = (memo[operation.name] || 0) + 1 if operation.name
        end

        groups.select { |_k, v| v.size > 1 }.keys
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
