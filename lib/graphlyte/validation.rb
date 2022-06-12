# frozen_string_literal: true

require_relative './editors/collect_fragment_spreads'

module Graphlyte
  module Validation
    # type Query {
    #   dog: Dog
    # }
    #
    # enum DogCommand {
    #   SIT
    #   DOWN
    #   HEEL
    # }
    #
    # type Dog implements Pet {
    #   name: String!
    #   nickname: String
    #   barkVolume: Int
    #   doesKnowCommand(dogCommand: DogCommand!): Boolean!
    #   isHouseTrained(atOtherHomes: Boolean): Boolean!
    #   owner: Human
    # }
    #
    # interface Sentient {
    #   name: String!
    # }
    #
    # interface Pet {
    #   name: String!
    # }
    #
    # type Alien implements Sentient {
    #   name: String!
    #   homePlanet: String
    # }
    #
    # type Human implements Sentient {
    #   name: String!
    #   pets: [Pet!]
    # }
    #
    # enum CatCommand {
    #   JUMP
    # }
    #
    # type Cat implements Pet {
    #   name: String!
    #   nickname: String
    #   doesKnowCommand(catCommand: CatCommand!): Boolean!
    #   meowVolume: Int
    # }
    #
    # union CatOrDog = Cat | Dog
    # union DogOrHuman = Dog | Human
    # union HumanOrAlien = Human | Alien
    module DuplicateFieldsCanMerge

      # can_merge_duplicates?
      # if two fields have the same name but different arguments - they cannot be merged
      # if two fields have the same alias but different field values - they cannot be merged
      #
      # @return [Boolean] can merge duplicate fields?
      def can_merge_duplicates?

      end

      # @return [Array(Syntax::Field)] duplicate fields
      def duplicate_fields

      end
    end

    class Document
      attr_reader :schema, :document

      def initialize(schema)
        @schema = schema
      end

      def validate(document)
        values = {
          operations: [],
          fragments: []
        }

        document.definitions.each_with_object(values) do |definition, values|
          case definition
          when Syntax::Operation
            values[:operations] << definition
          when Syntax::Fragment
            values[:fragments] << definition
          end
        end
        operations = values[:operations].map { |op| Operation.new(schema, op) }
        fragments = values[:fragments].map { |fragment| Fragment.new(schema, fragment) }

        errors = []

        validate_duplicate_fragments(errors, fragments)

        validate_fragment_spreads(errors, document)

        operations.each_with_object(errors) do |op, operation_errors|
          op.validate(operation_errors)
        end

        raise Invalid.new(*errors) unless errors.empty?
      end

      def validate_fragment_spreads(errors, document)
        spreads = Editors::CollectFragmentSpreads.new.edit(document)

        spreads[:spreads].each do |hash|
          type = hash[:ref].type_name

          errors << "#{hash[:name]} target #{type} not found" unless schema.types[type]
          errors << "#{hash[:name]} target #{type} must be kind of UNION, INTERFACE, or OBJECT" unless validate_fragment_type(hash[:ref])
        end

        spreads[:inline].each do |inline|
          type = inline[:fragment].type_name

          errors << "inline target #{type} not found" unless schema.types[type]
          errors << "inline target #{type} must be kind of UNION, INTERFACE, or OBJECT" unless validate_fragment_type(inline[:fragment])
        end
      end

      def validate_fragment_type(fragment)
        [:UNION, :INTERFACE, :OBJECT].reduce(false) do |memo, type|
          schema.types[fragment.type_name]&.kind == type || memo
        end
      end

      def validate_duplicate_fragments(errors, fragments)
        fragment_errors = duplicate_fragments(fragments).map { |frag| "ambiguous fragment name #{frag}" }
        errors.concat(fragment_errors)
      end

      # @return [Array(String)] array of fragment names that are duplicates.
      def duplicate_fragments(fragments)
        results = fragments.each_with_object({}) do |frag, memo|
          memo[frag.fragment.name] = (memo[frag.fragment.name] || 0) + 1
        end

        results.select { |_name, count| count > 1 }.keys
      end

      # @return [Array(String, String)] array of offenders, ex: ['Query', 'getName']
      def duplicate_operations

      end

      # @return [Numeric] number of anonymous operations
      def anonymous_operations_count

      end
    end

    class Operation
      using Refinements::StringRefinement

      include DuplicateFieldsCanMerge
      attr_reader :schema, :operation

      def initialize(schema, operation)
        @schema = schema
        @operation = operation
      end

      # @return [Boolean] is operation anonymous?
      def anonymous?
        operation.name.nil?
      end

      def type_fields
        typedef = schema.types[operation.type.camelize_upper]

        typedef&.fields
      end

      def fields
        operation.selection.filter_map do |field|
          # todo: validate fragment spreads?
          Field.new(type_fields[field.name], field) if field.is_a?(Syntax::Field)
        end
      end

      def validate(errors)
        fields.each_with_object(errors) do |field, field_errors|
          field.validate(field_errors)
        end
      end
    end

    class Fragment
      include DuplicateFieldsCanMerge
      attr_reader :schema, :fragment

      def initialize(schema, fragment)
        @schema = schema
        @fragment = fragment
      end
    end

    # Field selections must exist on Object, Interface, and Union types.
    class Field
      attr_reader :schema_field, :field

      def initialize(schema_field, field)
        @schema_field = schema_field
        @field = field
      end

      def argument_definitions
        schema_field.arguments
      end

      def grouped_arguments
        field.arguments.group_by(&:name)
      end

      def validate(field_errors)
        validate_selection_presence(field_errors)
        validate_required_arguments(field_errors)
        validate_unique_arguments(field_errors)
      end

      def validate_required_arguments(field_errors)
        argument_definitions.each_with_object(field_errors) do |(name, definition), errors|
          arg = Argument.new(definition, grouped_arguments[name]&.first)

          errors << "argument #{name} on field #{field.name} is required" unless arg.present_if_required?
        end
      end

      def validate_unique_arguments(field_errors)
        results = field.arguments.each_with_object({}) do |arg, memo|
          memo[arg.name] = (memo[arg.name] || 0) + 1
        end

        duplicates = results.select { |_name, count| count > 1 }.keys

        field_errors.concat duplicates.map { |name| "ambiguous argument #{name} on field #{field.name}" }
      end

      def validate_selection_presence(errors)
        errors << "selection on field #{field.name} can't be empty" if subselection_must_not_be_empty? && empty_selection?
        errors << "selection on field #{field.name} must be empty" if subselection_must_be_empty? && !empty_selection?
      end

      def empty_selection?
        field.selection.empty?
      end

      # @return [Boolean] is field defined on schema?
      def defined?
        !schema_field.nil?
      end

      # if selectionType is scalar or enum
      # the subselection must be empty
      #
      # @return [Boolean] if selectionType scalar or enum?
      def subselection_must_be_empty?
        scalar? || enum?
      end


      # if selectionType is interface, union, or object
      # the subselection must not be empty
      #
      # @return [Boolean] should selection type be populated?
      def subselection_must_not_be_empty?
        interface? || union? || object?
      end

      def scalar?
        schema_field.type.kind == :SCALAR
      end

      def enum?
        schema_field.type.kind == :ENUM
      end

      def interface?
        schema_field.type.kind == :INTERFACE
      end

      def union?
        schema_field.type.kind == :UNION
      end

      def object?
        schema_field.type.kind == :OBJECT
      end
    end

    class Argument
      attr_reader :schema_argument, :argument, :definitions

      def initialize(schema_argument, argument, definitions: nil)
        @schema_argument = schema_argument
        @argument = argument
        @definitions = definitions
      end

      def non_null?
        schema_argument.type.kind == :NON_NULL
      end

      def default_value
        schema_argument.default_value
      end

      def present_if_required?
        if non_null? && default_value.nil?
          !argument.nil? && argument.value.type != :NULL
        else
          true
        end
      end
    end
  end
end