# frozen_string_literal: true

require_relative '../errors'

module Graphlyte
  module Parsing
    # Basic back-tracking parser, with parser-combinator methods and exceptional
    # control-flow.
    #
    # This class is just scaffolding - all domain specific parsing should
    # go in subclasses.
    class BacktrackingParser
      attr_reader :tokens
      attr_accessor :max_depth

      def initialize(tokens:, max_depth: nil)
        @tokens = tokens
        @index = -1
        @max_depth = max_depth
        @current_depth = 0
      end

      def inspect
        "#<#{self.class} @index=#{@index} @current=#{current.inspect} ...>"
      end

      def to_s
        inspect
      end

      def peek(offset: 0)
        @tokens[@index + offset] || raise("No token at #{@index + offset}")
      end

      def current
        @current ||= peek
      end

      def advance
        @current = nil
        @index += 1
      end

      def next_token
        advance
        current
      end

      def expect(type, value = nil)
        try_parse do
          t = next_token

          if value
            raise Expected.new(t, expected: value) unless t.type == type && t.value == value
          else
            raise Unexpected, t unless t.type == type
          end

          t.value
        end
      end

      def optional(&block)
        try_parse(&block)
      rescue ParseError, IllegalValue
        nil
      end

      def optional_list(&block)
        optional(&block) || []
      end

      def many(limit: nil, &block)
        ret = []

        until ret.length == limit
          begin
            ret << try_parse(&block)
          rescue ParseError
            return ret
          end
        end

        ret
      end

      def some(&block)
        one = yield
        rest = many(&block)

        [one] + rest
      end

      def try_parse
        idx = @index
        yield
      rescue ParseError => e
        @index = idx
        raise e
      rescue IllegalValue => e
        t = current
        @index = idx
        raise Illegal, t, e.message
      end

      def one_of(*alternatives)
        err = nil
        all_symbols = alternatives.all? { _1.is_a?(Symbol) }

        alternatives.each do |alt|
          case alt
          when Symbol then return try_parse { send(alt) }
          when Proc then return try_parse { alt.call }
          else
            raise 'Not an alternative'
          end
        rescue ParseError => e
          err = e
        end

        raise ParseError, "At #{current.location}: Expected one of #{alternatives.join(', ')}" if err && all_symbols
        raise err if err
      end

      def punctuator(token)
        expect(:PUNCTUATOR, token)
      end

      def name(value = nil)
        expect(:NAME, value)
      end

      def bracket(lhs, rhs, &block)
        expect(:PUNCTUATOR, lhs)
        raise TooDeep, current.location if too_deep?

        ret = subfeature(&block)

        expect(:PUNCTUATOR, rhs)

        ret
      end

      def too_deep?
        return false if max_depth.nil?

        @current_depth > max_depth
      end

      def subfeature
        d = @current_depth
        @current_depth += 1

        yield
      ensure
        @current_depth = d
      end
    end
  end
end
