# frozen_string_literal: true

module Graphlyte
  module Lexing
    Position = Struct.new(:line, :col) do
      def to_s
        "#{line}:#{col}"
      end
    end

    # A source file location
    class Location
      attr_reader :start_pos, :end_pos

      def initialize(start_pos, end_pos)
        @start_pos = start_pos
        @end_pos = end_pos
      end

      def to(location)
        self.class.new(start_pos, location.end_pos)
      end

      def self.eof
        new(nil, nil)
      end

      def eof?
        start_pos.nil?
      end

      def ==(other)
        other.is_a?(self.class) && to_s == other.to_s
      end

      def to_s
        return 'EOF' if eof?

        "#{start_pos}-#{end_pos}"
      end
    end
  end
end
