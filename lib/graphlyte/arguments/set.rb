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

      def resolve_lazy_special_args(parser_special_args)
        @values&.each do |key, value|
          if value.is_a?(Set)
            value.resolve_lazy_special_args(parser_special_args) if value.is_a?(Set)
          elsif value.is_a?(Array)
            value.each do |it|
              it.refresh(parser_special_args) if it.is_a?(Value)
              it.resolve_lazy_special_args(parser_special_args) if it.is_a?(Set)
            end
          else
            value.refresh(parser_special_args)
          end
          [key, value]
        end.to_h
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
        data.inject({}) do |memo, (k, v)|
          if v.is_a?(Array)
            memo[k] = v.map do |item|
              if item.is_a?(Value)
                item
              else
                Value.new(item)
              end
            end
          elsif v.is_a?(Hash)
            memo[k] = Set.new(v)
          else
            if v.is_a?(Value)
              memo[k] = v
            else
              memo[k] = Value.new(v)
            end
          end
          memo
        end
      end
    end
  end
end