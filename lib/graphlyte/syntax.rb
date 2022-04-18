# frozen_string_literal: true

require_relative './errors'

module Graphlyte
  module Syntax
    class Operation
      attr_reader :type
      attr_accessor :name, :variables, :directives, :selection

      def initialize(type: nil, **args)
        @type = type
        args.each do |name, value|
          send(:"#{name}=", value)
        end
      end

      def eql?(other)
        other.is_a?(self.class) &&
          type == other.type &&
          name == other.name &&
          variables == other.variables &&
          directives == other.directives &&
          selection == other.selection
      end

      alias_method :==, :eql?

      def executable?
        true
      end

      def valid?
        !selection.empty? && valid_type?
      end

      def valid_type?
        [:query, :mutation, :subscription].include?(type)
      end

      def type=(value)
        @type = value
        raise IllegalValue, 'Expected query, mutation or subscription' unless valid_type?
      end
    end

    Field = Struct.new(:alias, :name, :arguments, :directives, :selection, keyword_init: true)

    Argument = Struct.new(:name, :value)
    Directive = Struct.new(:name, :arguments)

    FragmentSpread = Struct.new(:directives, :name) do
      def name=(value)
        raise IllegalValue, 'Not a legal fragment name' if value == 'on'

        @name = value
      end
    end

    InlineFragment = Struct.new(:type_name, :directives, :selection)

    Fragment = Struct.new(:name, :type_name, :directives, :selection) do
      def executable?
        true
      end

      def name=(value)
        raise IllegalValue, 'Not a legal fragment name' if value == 'on'

        @name = value
      end
    end

    class TypeSystemDefinition
      def executable?
        false
      end
    end

    EnumValue = Struct.new(:value)

    VariableDefinition = Struct.new(:variable, :type, :default_value, :directives, keyword_init: true)

    VariableReference = Struct.new(:name)

    class Type
      attr_accessor :inner, :is_list, :non_null

      def initialize(name = nil)
        @inner = name
        @is_list = false
        @non_null = false
      end

      def to_s
        str = inner.to_s
        str = "[#{str}]" if is_list
        str += '!' if non_null

        str
      end

      def eql?(other)
        other.is_a?(self.class) &&
          inner == other.inner &&
          is_list == other.is_list &&
          non_null == other.non_null
      end

      alias_method :==, :eql?
    end

    class NumericLiteral
      attr_reader :integer_part, :fractional_part, :exponent_part, :negated

      def initialize(integer_part, fractional_part, exponent_part, negated)
        @integer_part = integer_part
        @fractional_part = fractional_part
        @exponent_part = exponent_part
        @negated = negated
      end

      def eql?(other)
        other.is_a?(self.class) && to_s == other.to_s
      end

      alias_method :==, :eql?

      def floating?
        !!@fractional_part || !!@exponent_part
      end

      def to_s
        s = "#{negated ? '-' : ''}#{integer_part}"
        return s unless floating?

        s << ".#{fractional_part}" if fractional_part
        s << "e#{exponent_part.first}#{exponent_part.last}" if @exponent_part

        s
      end

      def to_i
        n = integer_part.to_i

        negated ? -n : n
      end
    end
  end
end
