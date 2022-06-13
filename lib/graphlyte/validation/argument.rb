# frozen_string_literal: true

module Graphlyte
  module Validation
    Argument = Struct.new(:schema, :schema_argument, :argument) do
      def non_null?
        schema_argument.type.kind == :NON_NULL
      end

      def default_value
        schema_argument.default_value
      end

      def present_if_required?
        if non_null? && default_value.nil?
          !argument.nil? && argument.value.type != :NULL
        else
          true
        end
      end
    end
  end
end