require "strscan"
require_relative "../fieldset"
require_relative "../query"
require_relative "../fragment"
require_relative "../schema_query"
require_relative "../types"

module Graphlyte
  module Schema
    module ParserHelpers
      def parse_fields
        fields = repeat(:parse_field)
        fields
      end

      def parse_field
        alias_field = expect(:ALIAS)
        if token = expect(:FRAGMENT_REF)
          raise "Can't find fragment #{token[0][1]}" unless fragments_dictionary[token[0][1]]
          fragments_dictionary[token[0][1]]
        elsif field = expect(:FIELD_NAME)
          args = parse_args
          if fieldset = parse_fieldset
            need(:END_FIELD)
            field = Field.new(field[0][1], fieldset, args)
          else
            field = Field.new(field[0][1], Fieldset.empty, args)
          end

          if alias_field
            field.alias(alias_field[0][1])
          end

          field
        end
      end

      def parse_fieldset
        if expect(:START_FIELD)
          fields = parse_fields
          Fieldset.new(builder: Builder.new(fields))
        end
      end

      def parse_args
        if expect(:START_ARGS)
          args = repeat(:parse_arg).inject(&:merge)
          need(:END_ARGS)
          args
        end
      end

      def parse_arg
        if (token = expect(:ARG_KEY)) && (value = parse_value)
          key = token[0][1]
          hash = {}
          hash[key] = value
          hash
        elsif (token = expect(:SPECIAL_ARG_KEY)) && (value = parse_value)
          @special_args ||= {}
          @special_args[token[0][1]] = value
          @special_args
        end
      end

      def parse_value
        if token = expect(:ARG_NUM_VALUE) || expect(:ARG_STRING_VALUE) || expect(:ARG_BOOL_VALUE)
          token[0][1]
        elsif token = expect(:SPECIAL_ARG_REF)
          ref = token[0][1]
          raise "Can't find ref $#{ref}" unless @special_args[ref]
          value = @special_args[ref]
          hash = {}
          hash[ref] = Graphlyte::TYPES.send(value, ref.to_sym)
          hash
        elsif token = expect(:SPECIAL_ARG_VAL)
          token[0][1]
        elsif token = expect(:ARG_HASH_START)
          parse_arg_hash
        elsif expect(:ARG_ARRAY_START)
          parse_arg_array
        end
      end

      def parse_arg_array
        args = repeat(:parse_value)
        need(:ARG_ARRAY_END)
        args
      end

      def parse_arg_hash
        if (key = expect(:ARG_KEY)) && (value = parse_value)
          need(:ARG_HASH_END)
          hash = {}
          hash[key[0][1]] = value
          hash
        end
      end

      def repeat(method)
        results = []

        while result = send(method)
          results << result
        end

        results
      end

      def expect(*expected_tokens)
        upcoming = tokens[position, expected_tokens.size]
        if upcoming.map(&:first) == expected_tokens
          advance(expected_tokens.size)
          upcoming
        end
      end

      def need(*required_tokens)
        upcoming = tokens[position, required_tokens.size]
        expect(*required_tokens) or raise "Unexpected tokens. Expected #{required_tokens.inspect} but got #{upcoming.inspect}"
      end

      def advance(offset = 1)
        @position += offset
      end

      def sort_fragments(sorted = [], fragments)
        return sorted if !fragments || fragments.empty?
        fragment_tokens = fragments.shift

        current_ref = fragment_tokens.find do |token|
          token[0] == :FRAGMENT_REF
        end

        if current_ref
          exists = sorted.any? do |frags|
            frags.find do |el|
              el[0] == :START_FRAGMENT && el[1] == current_ref[1]
            end
          end
          if exists
            sorted << fragment_tokens
            sort_fragments(sorted, fragments)
          else
            fragments.push fragment_tokens
            sort_fragments(sorted, fragments)
          end
        else
          sorted << fragment_tokens
          sort_fragments(sorted, fragments)
        end
      end

      def take_fragments
        aggregate = @tokens.inject({taking: false, idx: 0,  fragments: []}) do |memo, token_arr|
          if token_arr[0] == :END_FRAGMENT
            memo[:fragments][memo[:idx]] << token_arr
            memo[:taking] = false
            memo[:idx] += 1
          elsif token_arr[0] === :START_FRAGMENT
            memo[:fragments][memo[:idx]] = [token_arr]
            memo[:taking] = true
          elsif memo[:taking]
            memo[:fragments][memo[:idx]] << token_arr
          end
          memo
        end
        aggregate[:fragments]
      end
    end

    class FragmentParser
      attr_reader :tokens, :position, :fragments_dictionary

      include ParserHelpers

      def initialize(tokens)
        @tokens = tokens.flatten(1)
        @position = 0
        @fragments_dictionary = {}
      end

      def parse_fragments
        repeat(:parse_fragment)
        fragments_dictionary
      end

      def parse_fragment
        if token = expect(:START_FRAGMENT)
          builder = Builder.new parse_fields
          fragment = Fragment.new(token[0][1], token[0][2], builder: builder)
          @fragments_dictionary[token[0][1]] = fragment
          need(:END_FRAGMENT)
        end
      end
    end

    class Parser
      attr_reader :tokens, :position, :fragments_dictionary

      include ParserHelpers

      def self.parse(gql)
        obj = new Lexer.new(gql).tokenize
        obj.parse
      end

      def initialize(tokens)
        @tokens = tokens
        @fragment_tokens = sort_fragments([], take_fragments)
        @fragments_dictionary = {}
        @fragments_dictionary = @fragment_tokens.any? ? FragmentParser.new(@fragment_tokens).parse_fragments : {}
        @position = 0
      end

      def parse
        if token = expect(:START_QUERY)
          parse_query(token[0][1])
        elsif token = expect(:START_MUTATION)
          parse_mutation(token[1])
        else
          raise "INVALID"
        end
      end

      def parse_query(name)
        parse_args
        builder = Builder.new parse_fields
        query = Query.new(name, :query, builder: builder)
        need(:END_QUERY)
        query
      end

      def parse_mutation(name)
        builder = Builder.new parse_fields
        mutation = Query.new(name, :mutation, builder: builder)
        need(:END_MUTATION)
        mutation
      end
    end

    class Lexer
      attr_reader :stack, :scanner

      def initialize(gql, scanner: StringScanner.new(gql))
        @original_string = gql
        @scanner = scanner
        @tokens = []
      end

      SPECIAL_ARG_REGEX = /^\s*(?:(?<![\"\{]))([\w\!\[\]]+)(?:(?![\"\}]))/
      SIMPLE_EXPRESSION = /(query|mutation|fragment)\s*\w+\s*on\w*.*\{\s*\n*[.|\w\s]*\}/
      START_MAP = {
        'query' => :START_QUERY,
        'mutation' => :START_MUTATION,
        'fragment' => :START_FRAGMENT
      }

      def tokenize
        until scanner.eos?
          case state
          when :default
            if scanner.scan /^query (\w+)/
              @tokens << [:START_QUERY, scanner[1]]
              push_state :query
            elsif scanner.scan /^mutation (\w+)/
              @tokens << [:START_MUTATION, scanner[1]]
              push_state :mutation
            elsif scanner.scan /\s*fragment\s*(\w+)\s*on\s*(\w+)/
              @tokens << [:START_FRAGMENT, scanner[1], scanner[2]]
              push_state :fragment
            elsif scanner.scan /\s*{\s*/
              @tokens << [:START_FIELD]
              push_state :field
            elsif scanner.scan /\s*}\s*/
              @tokens << [:END_EXPRESSION_SHOULDNT_GET_THIS]
            else
              advance
            end
          when :fragment
            if scanner.scan /\s*\}\s*/
              @tokens << [:END_FRAGMENT]
              pop_state
              pop_context
            elsif scanner.check /^\s*\{\s*$/
              if get_context == :field
                push_state :field
                push_context :field
              else
                scanner.scan /^\s*\{\s*$/
                push_context :field
              end
            else
              handle_field
            end
          when :mutation
            if scanner.scan /\}/
              @tokens << [:END_MUTATION]
              pop_state
              pop_context
            elsif scanner.check /^\s*\{\s*$/
              if get_context == :field
                push_state :field
              else
                scanner.scan /^\s*\{\s*$/
                push_context :field
              end
            else
              handle_field
            end
          when :query
            if scanner.scan /\}/
              @tokens << [:END_QUERY]
              pop_state
              pop_context
            elsif scanner.check /^\s*\{\s*$/
              if get_context == :field
                push_state :field
                push_context :field
              else
                scanner.scan /^\s*\{\s*$/
                push_context :field
              end
            else
              handle_field
            end
          when :field
            if scanner.check /\s*\}\s*/
              if get_context == :field
                scanner.scan /\s*\}\s*/
                @tokens << [:END_FIELD]
                pop_state
              else
                pop_state
              end
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
          when :special_args
            handle_special_args
          end
        end
        @tokens
      end

      private

      def handle_field
        if scanner.scan /\s*\{\s*/
          @context = :field
          @tokens << [:START_FIELD]
          push_state :field
        elsif scanner.check /\.{3}(\w+)\s*\}/
          scanner.scan /\.{3}(\w+)/
          @tokens << [:FRAGMENT_REF, scanner[1]]
          pop_context
          pop_state if scanner.check /\s*\}\s*\}/
        elsif scanner.scan /\.{3}(\w+)/
          @tokens << [:FRAGMENT_REF, scanner[1]]
        elsif scanner.scan /\s*(\w+):\s*/
          @tokens << [:ALIAS, scanner[1]]
        elsif scanner.check /\s*(\w+)\s*\}/
          scanner.scan /\s*(\w+)\s*/
          @tokens << [:FIELD_NAME, scanner[1]]
          pop_context
          pop_state if scanner.check /\s*\}\s*\}/
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
        elsif scanner.scan /^\s*\{\s*?/
          @tokens << [:ARG_HASH_START]
          push_state :hash_arguments
        elsif scanner.scan /\s*\[\s*/
          @tokens << [:ARG_ARRAY_START]
          push_state :array_arguments
        elsif scanner.scan /\s?\"([\w\s]+)\"/
          @tokens << [:ARG_STRING_VALUE, scanner[1]]
        elsif scanner.scan /\s?(\d+)/
          @tokens << [:ARG_NUM_VALUE, scanner[1].to_i]
        elsif scanner.scan /\s?(true|false)\s?/
          bool = scanner[1] == "true"
          @tokens << [:ARG_BOOL_VALUE, bool]
        elsif scanner.scan /\$(\w+):/
          @tokens << [:SPECIAL_ARG_KEY, scanner[1]]
          push_state :special_args
        elsif scanner.scan /\$(\w+)/
          @tokens << [:SPECIAL_ARG_REF, scanner[1]]
        else
          advance
        end
      end

      def handle_special_args
        if scanner.check SPECIAL_ARG_REGEX
          scanner.scan SPECIAL_ARG_REGEX
          @tokens << [:SPECIAL_ARG_VAL, scanner[1]]
          pop_state
        else
          pop_state
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

      def env
        @ctx ||= []
      end

      def get_context
        env.last || :default
      end

      def push_context(context)
        env << context
      end

      def pop_context
        env.pop
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