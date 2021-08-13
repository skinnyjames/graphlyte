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
        values.each do |key, value|
          if value.is_a?(Set)
            variables.concat extract_variables(value.values)
          elsif value.symbol?
            variables << value
          end
        end
        variables
      end

      def to_h(inner = false)
        return {} unless values && !values.empty?
        values.inject({}) do |memo, (k, v)|
          if v.is_a?(Array)
            memo[k.to_s.to_camel_case] = v.map(&:to_s)
          elsif v.is_a?(Set)
            memo[k.to_s.to_camel_case] = v.to_h
          else
            memo[k.to_s.to_camel_case] = v.to_s
          end
          memo
        end
      end
      
      def to_s(inner = false)
        return "" unless values && !values.empty?
        arr = values.map do |k,v| 
          if v.is_a?(Array)
            "#{k.to_s.to_camel_case}: [#{v.map(&:to_s).join(", ")}]"
          elsif v.is_a?(Set)
            "#{k.to_s.to_camel_case}: { #{v.to_s(true)} }"
          else
            "#{k.to_s.to_camel_case}: #{v.to_s}"
          end
        end
        return arr.join(", ") if inner
        "(#{arr.join(", ")})"
      end

      private 

      def expand_arguments(data)
        data.inject({}) do |memo, (k, v)|
          if v.is_a?(Array)
            memo[k] = v.map do |item|
              Value.new(item)
            end
          elsif v.is_a?(Hash)
            memo[k] = Set.new(v)
          else
            memo[k] = Value.new(v)
          end
          memo
        end
      end
    end
  end
end