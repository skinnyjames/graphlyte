# frozen_string_literal: true

require_relative './errors'

module Graphlyte
  module Syntax
    module StructuralEquality
      def hash
        state.hash
      end

      def eql?(other)
        other.class == self.class && state == other.state
      end

      alias_method :==, :eql?
    end

    class Operation
      include StructuralEquality

      attr_reader :type
      attr_accessor :name, :variables, :directives, :selection

      def initialize(type: nil, **args)
        args.each do |name, value|
          send(:"#{name}=", value)
        end
        self.type = type
      end

      def eql?(other)
        other.is_a?(self.class) &&
          type == other.type &&
          name == other.name &&
          variables == other.variables &&
          directives == other.directives &&
          selection == other.selection
      end

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

      private

      def state
        [type, name, variables, directives, selection]
      end
    end

    Argument = Struct.new(:name, :value)
    Directive = Struct.new(:name, :arguments)

    module HasFragmentName
      attr_reader :name

      def name=(value)
        raise IllegalValue, 'Not a legal fragment name' if value == 'on'

        @name = value
      end
    end

    Field = Struct.new(:as, :name, :arguments, :directives, :selection, keyword_init: true) do
      def simple?
        as.nil? && Array(arguments).empty? && Array(directives).empty? && Array(selection).empty?
      end
    end

    class FragmentSpread
      include HasFragmentName
      include StructuralEquality

      def initialize(name = nil)
        @name = name
      end

      def simple?
        false
      end

      attr_accessor :directives

      def state
        [name, directives]
      end
    end

    InlineFragment = Struct.new(:type_name, :directives, :selection) do
      def simple?
        false
      end
    end

    class Fragment
      include StructuralEquality
      include HasFragmentName

      attr_accessor :type_name, :directives, :selection

      def initialize
        @refers_to = []
      end

      def refers_to(fragment)
        @refers_to << fragment
      end

      def required_fragments
        [self] + @refers_to
      end

      def executable?
        true
      end
    end

    class TypeSystemDefinition
      def executable?
        false
      end
    end

    Literal = Struct.new(:value, :type, :to_s)
    NULL = Literal.new(nil, :NULL, 'null').freeze
    TRUE = Literal.new(true, :BOOL, 'true').freeze
    FALSE = Literal.new(false, :BOOL, 'false').freeze

    VariableDefinition = Struct.new(:variable, :type, :default_value, :directives, keyword_init: true)

    VariableReference = Struct.new(:name) do
      def serialize
        name
      end
    end

    class Type
      include StructuralEquality

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

      private

      def state
        [inner, is_list, non_null]
      end
    end

    class Value
      include StructuralEquality

      attr_reader :value, :type

      def initialize(value, type = value.type)
        @value = value
        @type = type
      end

      def serialize
        case value
        when NumericLiteral, Literal, Symbol
          value.to_s
        when String
          # TODO: handle block strings?
          '"' + value.gsub(/"/, '\"').gsub("\n", '\n').gsub("\t", '\t') + '"'
        end
      end

      def self.from_ruby(object)
        case object
        when Hash
          object.transform_keys(&:to_s).transform_values { from_ruby(_1) }
        when Array
          object.map { from_ruby(_1) }
        when String
          Value.new(object, :STRING)
        when Symbol
          Value.new(object, :ENUM)
        when Integer, Float
          Value.new(RubyNumber.new(object), :NUMBER)
        when TrueClass
          Value.new(TRUE)
        when FalseClass
          Value.new(FALSE)
        when NilClass
          Value.new(NULL)
        else
          raise IllegalValue, object
        end
      end

      private def state
        [@value, @type]
      end
    end

    class NumericLiteral
      include StructuralEquality

      attr_reader :integer_part, :fractional_part, :exponent_part, :negated

      def initialize(integer_part, fractional_part = nil, exponent_part = nil, negated = false)
        @integer_part = integer_part
        @fractional_part = fractional_part
        @exponent_part = exponent_part
        @negated = negated
      end

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

      private def state
        to_s
      end
    end

    class RubyNumber < NumericLiteral
      def initialize(number)
        @number = number
      end

      def to_s
        @number.to_s
      end

      def to_i
        @number.to_i
      end
    end
  end
end
