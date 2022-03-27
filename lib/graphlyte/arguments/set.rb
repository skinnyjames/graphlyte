require_relative "./value"
require_relative "./../refinements/string_refinement"
module Graphlyte
  module Arguments
    class Set
      using Refinements::StringRefinement

      attr_reader :values

      def initialize(data)
        raise ArgumentError, "input #{data} must be a hash" unless data.nil? || data.is_a?(Hash)
        @values = expand_arguments(data) unless data.nil?
      end

      def extract_variables(values=@values, variables=[])
        values&.each do |key, value|
          if value.is_a?(Set)
            variables.concat extract_variables(value.values)
          elsif value.is_a?(Array)
          elsif value.symbol?
            variables << value
          elsif value.formal?
            variables << value
          end
        end
        variables
      end

      def to_h(raw = false)
        return {} unless values && !values.empty?
        values.inject({}) do |memo, (k, v)|
          if v.is_a?(Array)
            memo[k.to_s.to_camel_case] = v.map { |value| value.to_s(raw) }
          elsif v.is_a?(Set)
            memo[k.to_s.to_camel_case] = v.to_h
          else
            memo[k.to_s.to_camel_case] = v.to_s(raw)
          end
          memo
        end
      end
      
      def to_s(inner = false)
        return "" unless values && !values.empty?
        arr = stringify_arguments
        return arr.join(", ") if inner
        "(#{arr.join(", ")})"
      end

      private 

      def stringify_arguments
        values.map do |k,v|
          if v.is_a?(Array)
            "#{k.to_s.to_camel_case}: [#{v.map(&:to_s).join(", ")}]"
          elsif v.is_a?(Set)
            "#{k.to_s.to_camel_case}: { #{v.to_s(true)} }"
          else
            "#{k.to_s.to_camel_case}: #{v.to_s}"
          end
        end
      end

      def expand_arguments(data)
        data.transform_values do |value|
          case value
          when Array
            value.map { |item| Value.from(item) }
          when Hash
            Set.new(value)
          else
            Value.from(value)
          end
        end
      end
    end
  end
end
