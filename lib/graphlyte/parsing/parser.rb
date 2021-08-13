require_relative "./lexer.rb"
require_relative "./../fieldset"
require_relative "./../field"
require_relative "./../builder"
require_relative "./../arguments/set"

module Graphlyte
  module Parsing
    class Parser

      attr_reader :tokens, :position, :state

      def self.parse(str, schema)
        tokens = Lexer.tokenize(str)
        new(tokens).parse(schema)
      end

      def initialize(tokens)
        @tokens = tokens
        @position = 0
      end

      def expect(*expected_tokens)
        upcoming = tokens[position, expected_tokens.size]
      
        if upcoming.map(&:first) == expected_tokens
          advance(expected_tokens.size)
          upcoming
        end
      end
      
      def advance(offset = 1)
        @position += offset
      end

      def parse(schema)
        advance(1)
        builder = Builder.new(parse_fields)
        schema.validate(builder)
        fieldset = Fieldset.new(builder: builder)
      end

      def parse_fields
        results = []
        while result = parse_field
          expect(:SEPARATOR)
          results << result
        end
        results
      end

      def parse_field
        parse_content_with_fieldset || parse_content
      end


      def parse_argument_key
        if args = expect(:START_ARGUMENTS, :CONTENT, :ARGUMENT_SEPARATOR)
          args[1][1]
        end
      end

      def parse_argument_value
        if expect(:START_OBJECT_VALUE)
        
        end
      end

      def parse_argument_object_value
        
      end

      def parse_arguments
        if args = expect(:START_ARGUMENTS, :CONTENT, :ARGUMENT_SEPARATOR, :CONTENT, :END_ARGUMENTS)
          { args[1][1] => args[3][1]}
        else
          {}
        end
      end

      def parse_content
        if content = expect(:CONTENT)
          args = parse_arguments
          Field.new(content.flatten[1], Fieldset.empty, args)
        end
      end

      def parse_content_with_fieldset
        if args = expect(:CONTENT, :START_FIELDSET)
          content, fieldset = *args
          builder = Builder.new(parse_fields)
          Field.new(content[1], Fieldset.new(builder: builder), {})
        end
      end

    
      def parse_field_name(initial_char='')
        while token = tokens[position]
          return initial_char unless token[0] == :CONTENT
          @position += 1
          initial_char << token[1]
        end
        initial_char
      end
    end
  end
end
