# frozen_string_literal: true

require_relative './errors'
require_relative './syntax'

module Graphlyte
  class Parser
    def initialize(tokens:)
      @tokens = tokens
      @index = -1
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
      doc = Graphlyte::Syntax::Document.new

      until index >= @tokens.length
        doc << definition
      end

      doc
    end

    def definition
      one_of(:executable_definition, :type_definition)
    end

    def executable_definition
      one_of(:operation, :fragment)
    end

    def operation
      op = Graphlyte::Syntax::Operation.new

      t = next_token

      case t.type
      when :PUNCTATOR
        op.type = :query
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
        some { one_of(:fragment_spread, :inline_fragment, :field_selection) }
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
      t = next_token

      if value
        raise Expected.new(t, expected: value) unless t.type == type && t.value == value
      else
        raise Unexpected, t unless t.type == type
      end

      t.value
    end

    def field_selection
      field = Graphlyte::Syntax::Field.new

      field.alias = optional do
        n = parse_name
        expect(:PUNCTATOR, ':')

        n
      end

      field.name = parse_name
      field.arguments = optional { arguments }
      field.directives = directives
      field.selection = optional { selection_set }

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
      when :STRING
        t.value
      when :NUMBER
        t.value
      when :NAME
        case t.value
        when 'true'
          true
        when 'false'
          false
        when 'null'
          nil
        else
          Graphlyte::Syntax::EnumValue.new(t.value)
        end
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

          var.default_value = default_value
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

    def list_type_name
      advance

      bracket('[', ']') { type_name }
    end

    def bracket(lhs, rhs)
      expect(:PUNCTATOR, lhs)

      ret = yield

      expect(:PUNCTATOR, rhs)

      ret
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
      # TODO
    end

    def one_of(*alternatives)
      err = nil

      alternatives.each do |alt|
        begin
          case alt
          when Symbol
            return try_parse { send(alt) }
          when Proc
            return try_parse { alt.call }
          else
            raise 'Not an alternative'
          end
        rescue ParseError => ex
          err = ex
        end
      end

      raise err if err
    end

    def optional
      try_parse { yield }
    rescue ParseError, IllegalValue
      nil
    end

    def many(limit: nil)
      ret = []

      until ret.length == limit
        begin
          ret << try_parse { yield }
        rescue ParseError
          return ret
        end
      end

      ret
    end

    def some
      one = yield
      rest = many { yield }

      [one] + rest
    end

    def try_parse
      idx = @index
      yield
    rescue ParseError => ex
      @index = idx
      raise ex
    rescue IllegalValue => ex
      t = current
      @index = idx
      raise Illegal, t, ex.message
    end
  end
end
