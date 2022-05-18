# frozen_string_literal: true

require 'forwardable'

module Graphlyte
  module Lexing
    # A lexical token
    class Token
      extend Forwardable

      attr_reader :type, :lexeme, :location

      def_delegators :@location, :line, :col, :length

      def initialize(type, lexeme, location, value: nil)
        @type = type
        @lexeme = lexeme
        @value = value
        @location = location
      end

      def value
        @value || @lexeme
      end

      def punctator?(value)
        @type == :PUNCTATOR && @lexeme == value
      end
    end
  end
end
