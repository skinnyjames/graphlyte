# frozen_string_literal: true

require_relative './errors'
require_relative './syntax'
require_relative './document'
require_relative './parsing/backtracking_parser'

module Graphlyte
  # A parser of GraphQL documents from a stream of lexical tokens.
  class Parser < Parsing::BacktrackingParser
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
      t = next_token

      case t.type
      when :PUNCTUATOR
        @index -= 1
        implicit_query
      when :NAME
        operation_from_kind(t.value.to_sym)
      else
        raise Unexpected, t
      end
    end

    def implicit_query
      Graphlyte::Syntax::Operation.new(type: :query, selection: selection_set)
    end

    def operation_from_kind(kind)
      op = Graphlyte::Syntax::Operation.new

      try_parse do
        op.type = kind
        op.name = optional { name }
        op.variables = optional { variable_definitions }
        op.directives = directives
        op.selection = selection_set
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

      punctuator('...')
      frag.name = name
      frag.directives = directives

      frag
    end

    def inline_fragment
      punctuator('...')
      name('on')

      frag = Graphlyte::Syntax::InlineFragment.new

      frag.type_name = name
      frag.directives = directives
      frag.selection = selection_set

      frag
    end

    def field_selection
      field = Graphlyte::Syntax::Field.new

      field.as = optional do
        n = name
        punctuator(':')

        n
      end

      field.name = name
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

      arg.name = name
      expect(:PUNCTUATOR, ':')
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
      when :PUNCTUATOR
        case t.value
        when '$'
          Graphlyte::Syntax::VariableReference.new(name)
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
          n = name
          expect(:PUNCTUATOR, ':')
          value = parse_value

          [n, value]
        end.to_h
      end
    end

    def directives
      ret = []
      while peek(offset: 1).punctuator?('@')
        d = Graphlyte::Syntax::Directive.new

        expect(:PUNCTUATOR, '@')
        d.name = name
        d.arguments = optional { arguments }

        ret << d
      end

      ret
    end

    def operation_type
      raise Unexpected, current unless current.type == :NAME

      current.value.to_sym
    end

    def variable_definitions
      bracket('(', ')') do
        some do
          var = Graphlyte::Syntax::VariableDefinition.new

          var.variable = variable_name
          expect(:PUNCTUATOR, ':')
          var.type = type_name

          var.default_value = optional { default_value }
          var.directives = directives

          var
        end
      end
    end

    def default_value
      expect(:PUNCTUATOR, '=')

      parse_value
    end

    def variable_name
      expect(:PUNCTUATOR, '$')

      name
    end

    def type_name
      ty = one_of(-> { Graphlyte::Syntax::Type.new(name) }, :list_type_name)

      t = peek(offset: 1)
      ty.non_null = t.punctuator?('!')
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

    def fragment
      frag = Graphlyte::Syntax::Fragment.new

      expect(:NAME, 'fragment')
      frag.name = name

      expect(:NAME, 'on')

      frag.type_name = name
      frag.directives = directives
      frag.selection = selection_set

      frag
    end

    def type_definition
      raise ParseError, "TODO: #{current.location}"
    end
  end
end
