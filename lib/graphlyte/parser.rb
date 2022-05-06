# frozen_string_literal: true

require_relative './errors'
require_relative './syntax'
require_relative './document'

module Graphlyte
  class Parser
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

    def document
      doc = Graphlyte::Document.new
      doc.definitions = some { definition }

      expect(:EOF)

      doc
    end

    # Restricted parser: only parses executable definitions
    def query
      doc = Graphlyte::Document.new
      doc.definitions = some { executable_definition }

      expect(:EOF)

      doc
    end

    def definition
      one_of(:executable_definition, :type_definition)
    end

    def executable_definition
      one_of(:fragment, :operation)
    end

    def operation
      op = Graphlyte::Syntax::Operation.new

      t = next_token

      case t.type
      when :PUNCTATOR
        op.type = :query
        @index -= 1
        op.selection = selection_set
      when :NAME
        try_parse do
          op.type = t.value.to_sym
          op.name = optional { parse_name }
          op.variables = optional { variable_definitions }
          op.directives = directives
          op.selection = selection_set
        end
      else
        raise Unexpected, t
      end

      op
    end

    def selection_set
      bracket('{', '}') do
        some { one_of(:inline_fragment, :fragment_spread, :field_selection) }
      end
    end

    def fragment_spread
      frag = Graphlyte::Syntax::FragmentSpread.new

      expect(:PUNCTATOR, '...')

      frag.name = parse_name
      frag.directives = directives

      frag
    end

    def inline_fragment
      frag = Graphlyte::Syntax::InlineFragment.new

      expect(:PUNCTATOR, '...')
      expect(:NAME, 'on')

      frag.type_name = parse_name
      frag.directives = directives
      frag.selection = selection_set

      frag
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

    def field_selection
      field = Graphlyte::Syntax::Field.new

      field.as = optional do
        n = parse_name
        expect(:PUNCTATOR, ':')

        n
      end

      field.name = parse_name
      field.arguments = optional_list { arguments }
      field.directives = directives
      field.selection = optional_list { selection_set }

      field
    end

    def arguments
      bracket('(', ')') { some { parse_argument } }
    end

    def parse_argument
      arg = Graphlyte::Syntax::Argument.new

      arg.name = parse_name
      expect(:PUNCTATOR, ':')
      arg.value = parse_value

      arg
    end

    def parse_value
      t = next_token

      case t.type
      when :STRING, :NUMBER
        Graphlyte::Syntax::Value.new(t.value, t.type)
      when :NAME
        Graphlyte::Syntax::Value.from_name(t.value)
      when :PUNCTATOR
        case t.value
        when '$'
          Graphlyte::Syntax::VariableReference.new(parse_name)
        when '{'
          @index -= 1
          parse_object_value
        when '['
          @index -= 1
          parse_array_value
        else
          raise Unexpected, t
        end
      else
        raise Unexpected, t
      end
    end

    def parse_array_value
      bracket('[', ']') { many { parse_value } }
    end

    def parse_object_value
      bracket('{', '}') do
        many do
          name = parse_name
          expect(:PUNCTATOR, ':')
          value = parse_value

          [name, value]
        end.to_h
      end
    end

    def directives
      ret = []
      while peek(offset: 1).punctator?('@')
        d = Graphlyte::Syntax::Directive.new

        expect(:PUNCTATOR, '@')
        d.name = parse_name
        d.arguments = optional { arguments }

        ret << d
      end

      ret
    end

    def operation_type
      raise Unexpected, current unless current.type == :NAME

      current.value.to_sym
    end

    def parse_name
      expect(:NAME)
    end

    def variable_definitions
      bracket('(', ')') do
        some do
          var = Graphlyte::Syntax::VariableDefinition.new

          var.variable = variable_name
          expect(:PUNCTATOR, ':')
          var.type = type_name

          var.default_value = optional { default_value }
          var.directives = directives

          var
        end
      end
    end

    def default_value
      expect(:PUNCTATOR, '=')

      parse_value
    end

    def variable_name
      expect(:PUNCTATOR, '$')

      parse_name
    end

    def type_name
      ty = one_of(-> { Graphlyte::Syntax::Type.new(parse_name) }, :list_type_name)

      t = peek(offset: 1)
      ty.non_null = t.punctator?('!')
      advance if ty.non_null

      ty
    end

    def type_name!
      ty = type_name
      expect(:EOF)

      ty
    end

    def list_type_name
      advance

      bracket('[', ']') { type_name }
    end

    def bracket(lhs, rhs, &block)
      expect(:PUNCTATOR, lhs)
      raise TooDeep, current.location if too_deep?

      ret = subfeature(&block)

      expect(:PUNCTATOR, rhs)

      ret
    end

    def too_deep?
      return false if max_depth.nil?

      @current_depth > max_depth
    end

    def fragment
      frag = Graphlyte::Syntax::Fragment.new

      expect(:NAME, 'fragment')

      frag.name = parse_name

      expect(:NAME, 'on')

      frag.type_name = parse_name
      frag.directives = directives
      frag.selection = selection_set

      frag
    end

    def type_definition
      raise ParseError, "TODO: #{current.location}"
    end

    def one_of(*alternatives)
      err = nil
      all_symbols = alternatives.all? { _1.is_a?(Symbol) }

      alternatives.each do |alt|
        case alt
        when Symbol
          return try_parse { send(alt) }
        when Proc
          return try_parse { alt.call }
        else
          raise 'Not an alternative'
        end
      rescue ParseError => e
        err = e
      end

      raise ParseError, "At #{current.location}: Expected one of #{alternatives.join(', ')}" if err && all_symbols
      raise err if err
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

    def subfeature
      d = @current_depth
      @current_depth += 1

      yield
    ensure
      @current_depth = d
    end
  end
end
