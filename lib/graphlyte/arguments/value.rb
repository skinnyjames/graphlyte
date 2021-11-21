require_relative "./../refinements/string_refinement"
module Graphlyte
  module Arguments
    class Value
      using Refinements::StringRefinement

      attr_reader :value, :default

      def initialize(value, default = nil)
        raise ArgumentError, "Hash not allowed in this context" if value.is_a? Hash
        if value.is_a?(Value)
          @value = value.value
          @default = value.default
        else
          @value = value
          @default = default
        end
      end

      def symbol?
        value.is_a? Symbol
      end

      def formal?
        value.is_a? Schema::Types::Base
      end

      def to_s
        return "$#{value.to_s.to_camel_case}" if value.is_a? Symbol
        return value if value.is_a? Numeric
        return "\"#{value}\"" if value.is_a? String
        return "null" if value.nil?
        return "$#{value.placeholder.to_camel_case}" if value.is_a? Schema::Types::Base
        value.to_s
      end
    end
  end
end
