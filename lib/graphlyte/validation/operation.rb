# frozen_string_literal: true

require_relative './field'

module Graphlyte
  module Validation
    Operations = Struct.new(:schema, :operations) do
      include Enumerable

      def validate(errors)
        each { |op| op.validate(errors) }
      end

      def each
        operations.each do |op|
          yield Operation.new(schema, op)
        end
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
