# frozen_string_literal: true

require_relative './errors'
require_relative './data'
require_relative './refinements/syntax_refinements'

module Graphlyte
  module Syntax
    # An operation represents a top-level executable definition of
    # a query, mutation or a subscription.
    # See: https://spec.graphql.org/October2021/#sec-Language.Operations
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
        %i[query mutation subscription].include?(type)
      end

      def type=(value)
        @type = value
        return if valid_type?

        raise IllegalValue,
              "Illegal value: #{value.inspect}. Expected query, mutation or subscription"
      end
    end

    class InputObjectArgument < Graphlyte::Data
      attr_accessor :name, :value

      def initialize(name = nil, value = nil, **kwargs)
        super(**kwargs)
        @name = name if name
        @value = value if value
      end
    end

    class InputObject < Graphlyte::Data
      attr_accessor :values

      def initialize(hash = {}, **opts)
        super(**opts)
        @values = expand(hash)
      end

      def expand(hash)
        hash.map do |k, v|
          arg = InputObjectArgument.new
          arg.name = k
          arg.value = v.instance_of?(Hash) ? InputObject.new(v) : v
          arg
        end
      end
    end

    # An argument to a Field
    # See: https://spec.graphql.org/October2021/#sec-Language.Arguments
    class Argument < Graphlyte::Data
      attr_accessor :name, :value

      def initialize(name = nil, value = nil, **kwargs)
        super(**kwargs)
        @name = name if name
        @value = value if value
      end
    end

    Directive = Struct.new(:name, :arguments)

    # Clases that have fragment names may include this module
    module HasFragmentName
      def self.included(mod)
        mod.attr_reader :name
      end

      def name=(value)
        raise IllegalValue, 'Not a legal fragment name' if value == 'on'

        @name = value
      end
    end

    # A discrete piece of information in the Graph
    # See: https://spec.graphql.org/October2021/#sec-Language.Fields
    class Field < Graphlyte::Data
      attr_accessor :as, :name, :arguments, :directives, :selection
      # type is special: it is not part of the serialized Query, but
      # inferred from the schema. See: editors/annotate_types.rb
      attr_accessor :type

      def initialize(**kwargs)
        super
        @arguments ||= []
        @directives ||= []
        @selection ||= []
      end

      def simple?
        as.nil? && arguments.empty? && directives.empty? && selection.empty?
      end
    end

    # A reference to the use of a Fragment
    # See: https://spec.graphql.org/October2021/#FragmentSpread
    class FragmentSpread < Graphlyte::Data
      include HasFragmentName

      attr_accessor :directives

      def simple?
        false
      end
    end

    InlineFragment = Struct.new(:type_name, :directives, :selection) do
      def errors
        @errors ||= []
      end

      def simple?
        false
      end
    end

    # A definition of a re-usable chunk of an operation
    # See: https://spec.graphql.org/October2021/#sec-Language.Fragments
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

    Literal = Struct.new(:value, :type, :to_s) # rubocop:disable Lint/StructNewOverride
    NULL = Literal.new(nil, :NULL, 'null').freeze
    TRUE = Literal.new(true, :BOOL, 'true').freeze
    FALSE = Literal.new(false, :BOOL, 'false').freeze

    VariableDefinition = Struct.new(:variable, :type, :default_value, :directives, keyword_init: true)

    # A use of a variable in an operation or fragment
    # See: https://spec.graphql.org/October2021/#Variable
    class VariableReference < Graphlyte::Data
      attr_accessor :variable, :inferred_type

      def initialize(variable = nil, inferred_type = nil, **kwargs)
        super(**kwargs)
        @variable ||= variable
        @inferred_type ||= inferred_type
      end

      def to_definition
        VariableDefinition.new(variable: variable, type: inferred_type)
      end

      private

      def state
        @variable
      end
    end

    # A reference to a type, possibly containing other types.
    # See: https://spec.graphql.org/October2021/#sec-Type-References
    class Type < Graphlyte::Data
      attr_accessor :inner, :is_list, :non_null

      def initialize(name = nil, **kwargs)
        super(**kwargs)
        @inner ||= name
        @is_list ||= false
        @non_null ||= false
      end

      # Used during value->type inference
      # always non-null, because we have a value.
      def self.list_of(inner)
        t = new(inner)
        t.is_list = true
        t.non_null = true
        t
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

        inner = from_type_ref(type_ref.of_type) if type_ref.of_type

        case type_ref.kind
        when :NON_NULL
          non_null(inner)
        when :LIST
          list_type(inner)
        when :SCALAR, :OBJECT, :ENUM
          raise ArgumentError, "#{type_ref.kind} cannot have inner type" if inner

          new(inner: type_ref.name)
        else
          raise ArgumentError, "Unexpected kind: #{type_ref.kind.inspect}"
        end
      end

      def self.list_type(inner)
        raise ArgumentError, 'List types must have inner type' unless inner

        new(is_list: true, inner: inner)
      end

      def self.non_null(inner)
        raise ArgumentError, 'Non null types must have inner type' unless inner

        type = new(non_null: true, inner: inner)

        if inner.respond_to?(:is_list) && inner.is_list
          type.is_list = true
          type.inner = inner.inner
        end

        type
      end
    end

    # A CONST input value
    # See: https://spec.graphql.org/October2021/#sec-Input-Values
    class Value < Graphlyte::Data
      using Refinements::SyntaxRefinements

      attr_accessor :value, :type

      def initialize(value = nil, type = nil, **kwargs)
        super(**kwargs)
        @value = value if value
        @type = type if type
        @type ||= value&.type
      end

      def self.from_name(name)
        case name
        when 'true'
          true.to_input_value
        when 'false'
          false.to_input_value
        when 'null'
          nil.to_input_value
        else
          name.to_sym.to_input_value
        end
      end

      def inspect
        "#<#{self.class.name} @type=#{type} @value=#{value.inspect}>"
      end
      alias to_s inspect

      def eql?(other)
        return true if super
        return true if numeric_eql?(other)

        false
      end

      def numeric_eql?(other)
        return false unless number?
        return false unless other&.number?

        if floating? || other.floating?
          (value.to_f - other.value.to_f) < Float::EPSILON
        else
          value.to_i == other.value.to_i
        end
      end

      def floating?
        return false unless number?
        return true if value.is_a?(Float)
        return true if value.is_a?(NumericLiteral) && value.floating?

        false
      end

      def integer?
        number? && !floating?
      end

      def number?
        type == :NUMBER
      end

      def self.from_ruby(object)
        object.to_input_value
      rescue NoMethodError
        raise IllegalValue, object
      end
    end

    # A representation of a GraphQL literal, preserving the text components
    #
    # Note: NumericLiterals are immutable.
    class NumericLiteral < Graphlyte::Data
      attr_reader :integer_part, :fractional_part, :exponent_part, :negated

      def initialize(**kwargs)
        super
        @negated ||= false

        raise ArgumentError, 'integer_part is required' unless @integer_part

        freeze
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
        unnegate(negated, integer_part.to_i)
      end

      def to_f
        n = to_i.to_f
        n += fractional_value if fractional_part
        n *= exponent_value if exponent_part

        n
      end

      private

      attr_writer :integer_part, :fractional_part, :exponent_part, :negated

      def exponent_value
        10**unnegate(exponent_part.first, exponent_part.last.to_i)
      end

      def fractional_value
        fp = unnegate(negated, fractional_part.to_i.to_f)
        fp / (10**fractional_part.length)
      end

      def unnegate(negated, value)
        value * (negated ? -1 : 1)
      end
    end
  end
end
