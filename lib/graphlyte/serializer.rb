# frozen_string_literal: true

require_relative './syntax'

module Graphlyte
  class Serializer
    Unsupported = Class.new(ArgumentError)
    SPACE = ' '
    NEWLINE = "\n"

    attr_reader :buff, :indent
    attr_accessor :line_length, :max_fields_per_line

    def initialize(buff = [])
      @buff = buff
      @line_length = 100
      @max_fields_per_line = 5
      @indent = 0
    end

    def dump_definitions(definitions)
      return unless definitions&.any?

      definitions.each_with_index do |dfn, i|
        buff << NEWLINE << NEWLINE if i.positive?

        case dfn
        when Graphlyte::Syntax::Operation
          dump_operation(dfn)
        when Graphlyte::Syntax::Fragment
          dump_fragment(dfn)
        else
          raise Unsupported, dfn.class
        end
      end
    end

    def dump_operation(operation)
      buff << operation.type.to_s
      buff << " #{operation.name}" if operation.name
      dump_signature(operation.variables)
      dump_directives(operation.directives)
      dump_selection(operation.selection)
    end

    def dump_selection(selection)
      i = @indent

      return unless selection&.any?

      @indent += 2

      buff << SPACE << '{'

      if selection.length < max_fields_per_line && selection.all?(&:simple?) && (selection.sum { _1.name.length } + selection.length + indent) < line_length
        buff << SPACE
        selection.each do |field|
          buff << field.name
          buff << SPACE
        end
      else
        buff << NEWLINE
        buff << (SPACE * indent)
        selection.each_with_index do |selected, i|
          if i != 0
            buff << NEWLINE
            buff << (SPACE * indent)
          end

          case selected
          when Graphlyte::Syntax::Field
            dump_field(selected)
          when Graphlyte::Syntax::InlineFragment
            dump_inline_fragment(selected)
          when Graphlyte::Syntax::FragmentSpread
            dump_fragment_spread(selected)
          end
        end

        buff << NEWLINE
        buff << (SPACE * i)
      end

      buff << '}'
    ensure
      @indent = i
    end

    def dump_field(field)
      buff << "#{field.as}: " if field.as
      buff << field.name
      dump_arguments(field.arguments)
      dump_directives(field.directives)
      dump_selection(field.selection)
    end

    def dump_inline_fragment(frag)
      buff << '... on '
      buff << frag.type_name
      dump_directives(frag.directives)
      dump_selection(frag.selection)
    end

    def dump_fragment_spread(frag)
      buff << '...'
      buff << frag.name
      dump_directives(frag.directives)
    end

    def dump_directives(directives)
      return unless directives&.any?

      directives.each do |d|
        buff << ' @'
        buff << d.name
        dump_arguments(d.arguments)
      end
    end

    def dump_value(value)
      case value
      when Array
        # TODO: handle layout of large arrays nicely
        buff << '['
        value.each_with_index do |v, i|
          buff << ', ' * [i, 1].min
          dump_value(v)
        end
        buff << ']'
      when Hash
        # TODO: handle layout of large objects nicely
        buff << '{'
        value.each.each_with_index do |(k, v), i|
          buff << ', ' * [i, 1].min
          buff << k
          buff << ': '
          dump_value(v)
        end
        buff << '}'
      else
        buff << value.serialize
      end
    end

    def dump_arguments(args)
      return unless args&.any?

      buff << '('
      args.each_with_index do |arg, i|
        buff << ', ' * [i, 1].min
        buff << "#{arg.name}: "
        dump_value(arg.value)
      end
      buff << ')'
    end

    def dump_signature(variable_definitions)
      return unless variable_definitions
      return if variable_definitions.empty?

      buff << '('
      variable_definitions.each_with_index do |var, i|
        buff << ', ' * [i, 1].min
        buff << "$#{var.variable}: "
        buff << var.type.to_s
        buff << ' = ' if var.default_value
        dump_value(var.default_value) if var.default_value
        dump_directives(var.directives)
      end
      buff << ')'
    end

    def dump_fragment(fragment)
      buff << 'fragment '
      buff << fragment.name
      buff << ' on '
      buff << fragment.type_name
      dump_directives(fragment.directives)
      dump_selection(fragment.selection)
    end
  end
end
