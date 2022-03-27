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

      def skip_fieldset
        expect(:FIELDSET)
        parse_fields
        need(:END_FIELDSET)
      end

      def parse_field
        alias_field = expect(:ALIAS)
        if token = expect(:FRAGMENT_REF)
          raise "Can't find fragment #{token[0][1]}" unless fragments_dictionary[token[0][1]]
          fragments_dictionary[token[0][1]]
        elsif expect(:INLINE_FRAGMENT)
          field = parse_inline_fragment
        elsif expect(:FIELDSET)

        elsif (field = expect(:FIELD_NAME))
          args = parse_args
          directive = parse_directive

          if builder = parse_fieldset_into_builder
            need(:END_FIELDSET)
            fieldset = Fieldset.new(builder: builder)
            field = Field.new(field[0][1], fieldset, args, directive: directive)
          else
            field = Field.new(field[0][1], Fieldset.empty, args, directive: directive)
          end

          if alias_field
            field.alias(alias_field[0][1])
          end

          field
        end
      end

      def parse_inline_fragment
        model_name = expect(:MODEL_NAME)&.dig(0, 1)
        directive = parse_directive
        inputs = directive ? (parse_args || {}) : {}
        fields = expect(:FIELDSET) ? parse_fields : []
        need(:END_FIELDSET)

        InlineFragment.new(model_name, directive: directive, builder: Builder.new(fields), **inputs)
      end

      def parse_directive
        if token = expect(:DIRECTIVE)
          inputs = parse_args || {}

          Directive.new(token[0][1], **inputs)
        end
      end

      def parse_fieldset_into_builder
        fields = []
        if expect(:FIELDSET)
          fields = parse_fields
          Builder.new(fields)
        end
      end

      def parse_args
        if expect(:START_ARGS)
          args = repeat(:parse_arg).inject(&:merge)
          need(:END_ARGS)
          args
        end
      end

      def parse_default
        if expect(:DEFAULT_VALUE)
          value = parse_value
          need(:END_DEFAULT_VALUE)
          value
        end
      end

      def parse_arg
        if (token = expect(:ARG_KEY)) && (value = parse_value)
          defaults = parse_default
          key = token[0][1]
          hash = {}
          hash[key] = value
          hash
        elsif (token = expect(:SPECIAL_ARG_KEY)) && (value = parse_value)
          defaults = parse_default
          @special_args ||= {}
          arg = {}
          if [Array, Hash].include?(value.class)
            arg[token[0][1]] = value
          else
            new_val = Schema::Types::Base.new(value, token[0][1], defaults)
            arg[token[0][1]] = new_val
          end
          @special_args.merge!(arg)
          arg
        end
      end

      def parse_value
        if token = expect(:ARG_NUM_VALUE) || expect(:ARG_STRING_VALUE) || expect(:ARG_BOOL_VALUE) || expect(:ARG_FLOAT_VALUE)
          token[0][1]
        elsif token = expect(:SPECIAL_ARG_REF)
          ref = token[0][1]
          raise "Can't find ref $#{ref}" unless @special_args[ref]
          @special_args[ref]
        elsif token = expect(:SPECIAL_ARG_VAL)
          token[0][1]
        elsif token = expect(:ARG_HASH)
          parse_arg_hash
        elsif expect(:ARG_ARRAY)
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
          hash = {}
          hash[key[0][1]] = value
          hash
          if new_hash = parse_arg_hash
            hash.merge!(new_hash)
          else
            need(:ARG_HASH_END)
            hash
          end
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

      def tokens?
        !tokens[position].nil?
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
              el[0] == :FRAGMENT && el[1] == current_ref[1]
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

      def fetch_fragments(tokens = @tokens.dup, fragment_tokens = [], memo = { active: false, starts: 0, ends: 0, idx: 0 })
        token_arr = tokens.shift
        return fragment_tokens if token_arr.nil?


        if memo[:active] == true
          fragment_tokens[memo[:idx]] << token_arr
        end

        if token_arr[0] == :END_FIELDSET && memo[:active] == true
          memo[:ends] += 1
          fragment_tokens[memo[:idx]] << token_arr if memo[:starts] == memo[:ends]

          memo[:active] = false
          memo[:ends] = 0
          memo[:starts] = 0
          memo[:idx] += 1
        elsif token_arr[0] == :FRAGMENT
          memo[:active] = true
          memo[:starts] += 1
          fragment_tokens[memo[:idx]] = [token_arr]
        elsif token_arr[0] == :FIELDSET && memo[:active] == true
          memo[:starts] += 1
        end


        fetch_fragments(tokens, fragment_tokens, memo)
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
        if token = expect(:FRAGMENT)
          parse_args
          if builder = parse_fieldset_into_builder
            fragment = Fragment.new(token[0][1], token[0][2], builder: builder)
            need(:END_FIELDSET) if tokens?
          elsif fields = parse_fields
            builder = Builder.new(fields)
            fragment = Fragment.new(token[0][1], token[0][2], builder: builder)
          end
          @fragments_dictionary[token[0][1]] = fragment
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

        @fragment_tokens = sort_fragments([], fetch_fragments)
        @fragments_dictionary = {}
        @fragments_dictionary = @fragment_tokens.any? ? FragmentParser.new(@fragment_tokens).parse_fragments : {}
        @position = 0
      end

      def parse
        if token = expect(:EXPRESSION)
          parse_expression(token[0][1], token[0][2])
        elsif expect(:FRAGMENT)
          skip_fragments
          parse
        else
          raise "INVALID"
        end
      end

      def skip_fragments
        skip_fieldset
      end

      def parse_expression(type, name)
        parse_args
        fields = []
        builder = parse_fieldset_into_builder
        need(:END_FIELDSET)
        query = Query.new(name, type.to_sym, builder: builder)
        query
      end
    end

    class LexerError < StandardError; end

    class Lexer
      attr_reader :stack, :scanner
      def initialize(gql, scanner: StringScanner.new(gql))
        @original_string = gql
        @scanner = scanner
        @tokens = []
      end

      SPECIAL_ARG_REGEX = /^\s*(?:(?<![\"\{]))([\w\!\[\]]+)(?:(?![\"\}]))/

      def tokenize
        until scanner.eos?
          tokenize_objects
        end

        @tokens
      end

      def tokenize_objects
        case state
        when :default # the stack is empty, can only process top level fragments or expressions
          if scanner.scan %r{\s*fragment\s*(\w+)\s*on\s*(\w+)}
            @tokens << [:FRAGMENT, scanner[1], scanner[2]]
            push_context :fragments
            # check for a fieldset
            if scanner.check %r[\s*{]
              tokenize_fieldset
            else
              scanner.scan /\(/
              @tokens << [:START_ARGS]
              push_state :arguments
            end
          elsif scanner.check /\{/
            @tokens << [:EXPRESSION, 'query', nil] if get_context == :default
            push_context :fieldset

            tokenize_fieldset
          elsif scanner.scan %r{^(\w+) (\w+)?}
            @tokens << [:EXPRESSION, scanner[1], scanner[2]]
            push_context :expression
            # check for a fieldset
            if scanner.check %r[\s*{]
              tokenize_fieldset
            else
              scanner.scan /\(/
              @tokens << [:START_ARGS]
              push_state :arguments
            end
          elsif scanner.check /\s*\}/
            if get_context == :fragments
              end_fragment
            elsif get_context == :expression
              end_expression
            end
          else
            advance
          end
        when :fieldset
          tokenize_fields
        when :arguments
          tokenize_arguments
        when :argument_defaults
          tokenize_shared_arguments
        when :hash_arguments
          tokenize_hash_arguments
        when :array_arguments
          tokenize_array_arguments
        when :special_args
          tokenize_special_arguments
        when :inline_fragment
          tokenize_inline_fragment
        end
      end

      def check_for_last(regex = /\s*\}/)
        scanner.check regex
      end

      def check_for_final
        scanner.check /\s*\}(?!\s*\})/
      end

      def check_for_not_last
        scanner.check /\s*\}(?=\s*\})/
      end

      def tokenize_inline_fragment
        if scanner.scan /on (\w+)/
          @tokens << [:MODEL_NAME, scanner[1]]

          pop_state
        elsif scanner.scan /@(\w+)/
          @tokens << [:DIRECTIVE, scanner[1]]

          pop_state
        else
          # throw an error here?
          advance
        end
      end

      def end_fieldset
        scanner.scan /\s*\}/
        @tokens << [:END_FIELDSET]
        pop_state
      end

      def end_arguments
        scanner.scan /\s*\)/
        @tokens << [:END_ARGS]
        pop_state
      end

      # to tired to figure out why this is right now
      def tokenize_argument_defaults
        if scanner.scan /\)/
          @tokens << [:END_DEFAULT_VALUE]
          pop_state
        else
          tokenize_shared_arguments
        end
      end

      def tokenize_special_arguments
        if scanner.check SPECIAL_ARG_REGEX
          scanner.scan SPECIAL_ARG_REGEX

          @tokens << [:SPECIAL_ARG_VAL, scanner[1]]

          pop_state

          end_arguments if check_for_last(/\s*\)/)
        else
          # revisit this.. should we throw an error here?
          pop_state
          raise LexerError, "why can't we parse #{scanner.peek(5)}"
        end
      end

      def tokenize_array_arguments
        if scanner.scan /\]/
          @tokens << [:ARG_ARRAY_END]

          pop_state
          # if check_for_last(')')
          #   pop_state
          # end
        else
          tokenize_shared_arguments
        end
      end

      def tokenize_hash_arguments
        if scanner.scan /\}/
          @tokens << [:ARG_HASH_END]

          pop_state
          # if this is the last argument in the list, maybe get back to the field scope?
          # if check_for_last(')')
          #   pop_state
          # end
        else
          tokenize_shared_arguments
        end
      end

      def tokenize_arguments
        # pop argument state if arguments are finished
        if scanner.scan %r{\)}
          @tokens << [:END_ARGS]

          pop_state
        # something(argument: $argument = true)
        #                               ^
        elsif scanner.scan %r{=}
          @tokens << [:DEFAULT_VALUE]

          push_state :argument_defaults
        # noop, should expect this, but not important
        elsif scanner.scan %r{,}
          nil
        else
          tokenize_shared_arguments
        end
      end

      def tokenize_shared_arguments
        if scanner.scan /^(\w+):/
          @tokens << [:ARG_KEY, scanner[1]]
        elsif scanner.scan %r[{]
          @tokens << [:ARG_HASH]

          push_state :hash_arguments
        elsif scanner.scan /\[/
          @tokens << [:ARG_ARRAY]

          push_state :array_arguments
        elsif scanner.scan %r{"(.*?)"}
          @tokens << [:ARG_STRING_VALUE, scanner[1]]

          end_arguments if check_for_last(/\s*\)/)
        elsif scanner.scan /(\d+\.\d+)/
          @tokens << [:ARG_FLOAT_VALUE, scanner[1].to_f]

          end_arguments if check_for_last(/\s*\)/)
        elsif scanner.scan /(\d+)/
          @tokens << [:ARG_NUM_VALUE, scanner[1].to_i]

          end_arguments if check_for_last(/\s*\)/)
        elsif scanner.scan /(true|false)/
          @tokens << [:ARG_BOOL_VALUE, (scanner[1] == 'true')]

          end_arguments if check_for_last(/\s*\)/)
        elsif scanner.scan /\$(\w+):/
          @tokens << [:SPECIAL_ARG_KEY, scanner[1]]

          push_state :special_args
        elsif scanner.scan /\$(\w+)/
          @tokens << [:SPECIAL_ARG_REF, scanner[1]]

          end_arguments if check_for_last(/\s*\)/)
        elsif scanner.scan /,/
          # no-op
        elsif check_for_last(/\s*\)/)
          @tokens << [:END_DEFAULT_VALUE] if state == :argument_defaults
          end_arguments
          pop_state
        else
          advance
        end
      end

      def tokenize_fields
        if scanner.check %r[{]
          tokenize_fieldset
        # ... on Model - or - ... @directive
        elsif scanner.scan %r{\.{3}\s}
          @tokens << [:INLINE_FRAGMENT]
          push_state :inline_fragment
        # @directive
        elsif scanner.scan %r{@(\w+)}
          @tokens << [:DIRECTIVE, scanner[1]]
        # ...fragmentReference (check for last since it is a field literal)
        elsif scanner.scan /\.{3}(\w+)/
          @tokens << [:FRAGMENT_REF, scanner[1]]

          end_fieldset while check_for_last && state == :fieldset
        # alias:
        elsif scanner.scan %r{(\w+):}
          @tokens << [:ALIAS, scanner[1]]
        # fieldLiteral
        elsif scanner.scan %r{(\w+)}
          @tokens << [:FIELD_NAME, scanner[1]]

          end_fieldset while check_for_last && state == :fieldset
        # (arguments: true)
        elsif scanner.scan /^\s*\(/
          @tokens << [:START_ARGS]

          push_state :arguments
        else
          advance
        end
      end

      def tokenize_fieldset
        if scanner.scan %r[\s*{]
          @tokens << [:FIELDSET]

          push_state :fieldset
        else
          raise LexerError, "Expecting `{` got `#{scanner.peek(3)}`"
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
        unless scanner.check /\s/
          raise LexerError, "Unexpected Char: '#{scanner.peek(3)}'"
        end

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