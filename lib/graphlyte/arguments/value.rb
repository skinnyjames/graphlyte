module Graphlyte
  module Arguments
    class Value
      attr_reader :value

      def initialize(value)
        raise ArgumentError, "Hash not allowed in this context" if value.is_a? Hash
        @value = value
      end

      def to_s
        return value if value.is_a? Numeric
        return "\"#{value}\"" if value.is_a? String
        return "null" if value.nil?
        value.to_s
      end
    end
  end
end
