# frozen_string_literal: true

require_relative './errors'
require_relative './data'

module Graphlyte
  module Syntax
    class Operation < Graphlyte::Data
      attr_reader :type
      attr_accessor :name, :variables, :directives, :selection

      def initialize(type: nil, **args)
        super(**args)
        self.type = type if type
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
        raise IllegalValue, "Illegal value: #{value.inspect}. Expected query, mutation or subscription" unless valid_type?
      end
    end

    Argument = Struct.new(:name, :value)

    Directive = Struct.new(:name, :arguments)

    module HasFragmentName
      def self.included(mod)
        mod.attr_reader :name
      end

      def name=(value)
        raise IllegalValue, 'Not a legal fragment name' if value == 'on'

        @name = value
      end
    end

    class Field < Graphlyte::Data
      attr_accessor :as, :name, :arguments, :directives, :selection
      # type is special: it is not part of the serialized Query, but
      # inferred from the schema. See: editors/annotate_types.rb
      attr_accessor :type

      def simple?
        as.nil? && arguments.empty? && Array(directives).empty? && Array(selection).empty?
      end

      def arguments
        @arguments ||= []
      end
    end

    class FragmentSpread < Graphlyte::Data
      include HasFragmentName

      attr_accessor :directives

      def simple?
        false
      end
    end

    InlineFragment = Struct.new(:type_name, :directives, :selection) do
      def simple?
        false
      end
    end

    class Fragment < Graphlyte::Data
      include HasFragmentName

      attr_accessor :type_name, :directives, :selection

      def initialize(**kwargs)
        super
        @refers_to = []
      end

      def inline
        InlineFragment.new(type_name, directives, selection)
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

    # TODO: unify with Schema?
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

    VariableReference = Struct.new(:variable, :inferred_type) do
      def serialize
        "$#{variable}"
      end
    end

    class Type < Graphlyte::Data
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

      def unpack
        return inner if inner.is_a?(String)

        inner.unpack
      end

      def self.from_type_ref(type_ref)
        raise ArgumentError, 'type_ref cannot be nil' if type_ref.nil?

        type = new
        inner = from_type_ref(type_ref.of_type) if type_ref.of_type

        case type_ref.kind
        when :NON_NULL
          raise ArgumentError, "#{type_ref.kind} must have inner type" unless inner
          type.non_null = true
          if inner.is_list
            type.is_list = true
            type.inner = inner.inner
          else
            type.inner = inner
          end
        when :LIST
          raise ArgumentError, "#{type_ref.kind} must have inner type" unless inner
          type.is_list = true
          type.inner = inner
        when :SCALAR, :OBJECT, :ENUM
          raise ArgumentError, "#{type_ref.kind} cannot have inner type" if inner
          type.inner = type_ref.name
        else
          raise ArgumentError, "Unexpected kind: #{type_ref.kind.inspect}"
        end

        type
      end
    end

    class Value < Graphlyte::Data
      attr_reader :value, :type

      def initialize(value, type = value.type)
        @value = value
        @type = type
      end

      def self.from_name(name)
        case name
        when 'true'
          new(TRUE, :BOOL)
        when 'false'
          new(FALSE, :BOOL)
        when 'null'
          new(NULL, :NULL)
        else
          new(name.to_sym, :ENUM)
        end
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
          Value.new(object, :NUMBER)
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
    end

    class NumericLiteral < Graphlyte::Data
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
    end
  end
end
