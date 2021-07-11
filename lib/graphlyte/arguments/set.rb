require_relative "./value"
module Graphlyte
  module Arguments
    class Set

      attr_reader :values

      def initialize(data)
        raise ArgumentError, "input #{data} must be a hash" unless data.nil? || data.is_a?(Hash)
        @values = expand_arguments(data) unless data.nil?
      end
      
      def to_s(inner = false)
        return "" unless values && !values.empty?
        arr = values.map do |k,v| 
          if v.is_a?(Array)
            "#{k}: [#{v.map(&:to_s).join(", ")}]"
          elsif v.is_a?(Set)
            "#{k}: { #{v.to_s(true)} }"
          else
            "#{k}: #{v.to_s}"
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
      # end method
    end
  end
end