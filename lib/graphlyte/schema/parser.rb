require "strscan"
require_relative "../fieldset"
require_relative "../query"
require_relative "../fragment"
require_relative "../schema_query"
require_relative "../types"

module Graphlyte
  module Schema
    class Parser
      attr_reader :tokens

      def self.parse(gql)
        new(Lexer.new(gql).tokenize).tokens
      end

      def initialize(tokens)
        @tokens = tokens
      end
    end

    class Lexer
      attr_reader :stack, :scanner

      def initialize(gql, scanner: StringScanner.new(gql))
        @original_string = gql
        @scanner = scanner
        @tokens = []
      end

      def tokenize
        until scanner.eos?
          case state
          when :default
            if scanner.scan /^query (\w+)/
              @tokens << [:START_QUERY, scanner[1]]
              push_state :query
            elsif scanner.scan /^mutation (\w+)/
              @tokens << [:START_MUTATION, scanner[1]]
              push_state :field
            elsif scanner.scan /\s*fragment\s*(\w+)\s*on\s*(\w+)/
              @tokens << [:START_FRAMENT, scanner[1], scanner[2]]
              push_state :fragment
            else
              advance
            end
          when :fragment
            if scanner.scan /\}/
              @tokens << [:END_FRAGMENT]
              pop_state
            elsif scanner.scan /^\s*\{\s*$/
              push_state :field
            else
              handle_field
            end
          when :query
            if scanner.scan /\}/
              @tokens << [:END_QUERY]
              pop_state
            elsif scanner.scan /^\s*\{\s*$/
              # do nothing
              push_state :field
            else
              handle_field
            end
          when :field
            if scanner.scan /\s*\}\s*/
              @tokens << [:END_FIELD]
              pop_state
            else
              handle_field
            end
          when :hash_arguments
            handle_hash_arguments
          when :array_arguments
            handle_array_arguments
          when :arguments
            if scanner.scan /\s*\)\s*/
              @tokens << [:END_ARGS]
              pop_state
            elsif scanner.scan /\=/
              @tokens << [:START_DEFAULT_VALUE]
              push_state :argument_defaults
            elsif scanner.scan /,/
              #
            else
              handle_shared_arguments
            end
          when :argument_defaults
            if @stack.reverse.take(2).eql?([:argument_defaults, :argument_defaults])
              @tokens << [:END_DEFAULT_VALUE]
              pop_state
              pop_state
            else
              push_state :argument_defaults
              handle_shared_arguments
            end
          end
        end
        @tokens
      end

      private

      def handle_field
        if scanner.scan /\s*\{\s*/
          @tokens << [:START_FIELD]
        elsif scanner.scan /\.{3}(\w+)/
          @tokens << [:FRAGMENT_REF, scanner[1]]
        elsif scanner.scan /\s*(\w+):\s*/
          @tokens << [:ALIAS, scanner[1]]
        elsif scanner.scan /\s*(\w+)\s*/
          @tokens << [:FIELD_NAME, scanner[1]]
        elsif scanner.scan /^\s*\(/
          @tokens << [:START_ARGS]
          push_state :arguments
        else
          advance
        end
      end

      def handle_shared_arguments
        if scanner.scan /^(\w+):/
          @tokens << [:ARG_KEY, scanner[1]]
        elsif scanner.scan(/(\!\w+)/)
          @tokens << [:SPECIAL_ARG_KEY_VAL, scanner[1]]
        elsif scanner.scan /^\s*\{\s*?/
          @tokens << [:ARG_HASH_START]
          push_state :hash_arguments
        elsif scanner.scan /\s*\[\s*/
          @tokens << [:ARG_ARRAY_START]
          push_state :array_arguments
        elsif scanner.scan /\s?\"(\w+)\"/
          @tokens << [:ARG_STRING_VALUE, scanner[1]]
        elsif scanner.scan /\s?(\d+)/
          @tokens << [:ARG_NUM_VALUE, scanner[1].to_i]
        elsif scanner.scan /\s?(true|false)\s?/
          bool = scanner[1] == "true"
          @tokens << [:ARG_BOOL_VALUE, bool]
        elsif scanner.scan /\$(\w+):/
          @tokens << [:SPECIAL_ARG_KEY, scanner[1]]
        elsif scanner.scan /\$(\w+)/
          @tokens << [:SPECIAL_ARG_REF, scanner[1]]
        else
          advance
        end
      end

      def handle_hash_arguments
        if scanner.scan /\}/
          @tokens << [:ARG_HASH_END]
          pop_state
        else
          handle_shared_arguments
        end
      end

      def handle_array_arguments
        if scanner.scan /\s*\]\s*/
          @tokens << [:ARG_ARRAY_END]   
          pop_state   
        else
          handle_shared_arguments
        end
      end

      def rewind
        scanner.pos = scanner.pos - 1
      end

      def advance
        scanner.pos = scanner.pos + 1
      end

      def stack
        @stack ||= []
      end

      def state
        stack.last || :default
      end

      def push_state(state)
        stack << state
      end

      def pop_state
        stack.pop
      end
    end
  end
end