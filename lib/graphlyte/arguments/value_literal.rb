module Graphlyte
  module Arguments
    class ValueLiteral
      attr_reader :value

      def initialize(string)
        raise 'Value must be a string' unless string.class == String

        @value = string
      end

      def to_s
        @value
      end
    end
  end
end