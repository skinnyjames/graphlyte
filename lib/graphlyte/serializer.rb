# frozen_string_literal: true

require_relative './syntax'

module Graphlyte
  # Logic for writing a GraphQL document to a string
  class Serializer
    # Type directed serialization:
    module Refinements
      refine Syntax::VariableReference do
        def serialize(buff)
          buff << "$#{variable}"
        end
      end

      refine Syntax::Argument do
        def serialize(buff)
          buff << "#{name}: "
          value.serialize(buff)
        end
      end

      refine Syntax::VariableDefinition do
        def serialize(buff)
          buff << "$#{variable}: #{type}"
          if default_value
            buff << ' = '
            default_value.serialize(buff)
          end
          buff.dump_directives(self)
        end
      end

      refine Syntax::Directive do
        def serialize(buff)
          buff << ' @' << name
          buff.dump_arguments(self)
        end
      end

      refine Syntax::Field do
        def serialize(buff)
          buff << "#{as}: " if as
          buff << name
          buff.dump_arguments(self)
          buff.dump_directives(self)
          buff.dump_selection(self)
        end
      end

      refine Syntax::FragmentSpread do
        def serialize(buff)
          buff << '...' << name
          buff.dump_directives(self)
        end
      end

      refine Syntax::InlineFragment do
        def serialize(buff)
          buff << '... on ' << type_name
          buff.dump_directives(self)
          buff.dump_selection(self)
        end
      end

      refine Syntax::Operation do
        def serialize(buff)
          buff << type
          buff << " #{name}" if name
          buff.comma_separated(variables)
          buff.dump_directives(self)
          buff.dump_selection(self)
        end
      end

      refine Syntax::Fragment do
        def serialize(buff)
          buff << 'fragment ' << name << ' on ' << type_name
          buff.dump_directives(self)
          buff.dump_selection(self)
        end
      end

      refine Syntax::Value do
        def serialize(buff)
          buff << case value
                  when String
                    # TODO: handle block strings?
                    "\"#{value.gsub(/"/, '\"').gsub("\n", '\n').gsub("\t", '\t')}\""
                  else
                    value
                  end
        end
      end

      refine Array do
        def serialize(buff)
          # TODO: handle layout of large arrays nicely
          buff << '['
          each_with_index do |v, i|
            buff << (', ' * [i, 1].min)
            v.serialize(buff)
          end
          buff << ']'
        end
      end

      refine Hash do
        def serialize(buff)
          buff << '{'
          each.each_with_index do |(k, v), i|
            buff << (', ' * [i, 1].min)
            buff << k
            buff << ': '
            v.serialize(buff)
          end
          buff << '}'
        end
      end
    end

    using Refinements

    Unsupported = Class.new(ArgumentError)
    SPACE = ' '
    STEP = 2
    NEWLINE = "\n"

    attr_reader :buff, :indent
    attr_accessor :line_length, :max_fields_per_line

    def initialize(buff = [])
      @buff = buff
      @line_length = 100
      @max_fields_per_line = 5
      @indent = 0
    end

    def <<(chunk)
      @buff << chunk.to_s
      self
    end

    def dump_definitions(definitions)
      return unless definitions&.any?

      definitions.each_with_index do |dfn, i|
        buff << NEWLINE << NEWLINE if i.positive?
        dfn.serialize(self)
      rescue NoMethodError
        raise Unsupported, dfn.class
      end
    end

    def dump_selection(node)
      i = @indent
      selection = node.selection
      return unless selection&.any?

      @indent += STEP

      buff << SPACE << '{'

      if simple?(selection)
        dump_simple_selection(selection)
      else
        dump_indented_selection(selection)
      end

      buff << '}'
    ensure
      @indent = i
    end

    def next_line
      buff << NEWLINE << (SPACE * indent)
    end

    def dump_indented_selection(selection)
      selection.each do |selected|
        next_line

        selected.serialize(self)
      end

      buff << NEWLINE << (SPACE * (indent - STEP))
    end

    def simple?(selection)
      selection.length < max_fields_per_line &&
        selection.all?(&:simple?) &&
        (selection.sum { _1.name.length } + selection.length + indent) < line_length
    end

    def dump_simple_selection(selection)
      buff << SPACE
      selection.each do |selected|
        selected.serialize(self)
        buff << SPACE
      end
    end

    def dump_directives(node)
      node.directives&.each { _1.serialize(self) }
    end

    def comma_separated(collection)
      return unless collection
      return if collection.empty?

      buff << '('
      collection.each_with_index do |elem, i|
        buff << (', ' * [i, 1].min)
        elem.serialize(self)
      end
      buff << ')'
    end

    def dump_arguments(node)
      comma_separated(node.arguments)
    end
  end
end
