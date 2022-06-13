# frozen_string_literal: true

require_relative './argument'

module Graphlyte
  module Validation
    Fields = Struct.new(:schema, :operation) do
      include Enumerable
      using Refinements::StringRefinement

      def validate(errors)
        each { |field| field.validate(errors) }
      end

      def each
        fields = operation.selection.filter_map do |field|
          field_schema = type_fields&.dig(field.name)

          Field.new(schema, field_schema, field) if field.is_a?(Syntax::Field)
        end

        fields.each do |field|
          yield(field)
        end
      end

      def type_fields
        typedef = schema.types[operation.type.camelize_upper]

        typedef&.fields
      end
    end

    Field = Struct.new(:schema, :field_schema, :field) do
      def argument_definitions
        field_schema.arguments
      end

      def grouped_arguments
        field.arguments.group_by(&:name)
      end

      def validate(errors)
        return errors << "#{field.name} is not defined in usage" unless field_defined?

        validate_selection_presence(errors)
        validate_required_arguments(errors)
        validate_unique_arguments(errors)
      end

      def validate_required_arguments(errors)
        argument_definitions.each do |name, definition|
          arg = Argument.new(schema, definition, grouped_arguments[name]&.first)

          errors << "argument #{name} on field #{field.name} is required" unless arg.present_if_required?
        end
      end

      def validate_unique_arguments(errors)
        results = field.arguments.each_with_object({}) do |arg, memo|
          memo[arg.name] = (memo[arg.name] || 0) + 1
        end

        duplicates = results.select { |_name, count| count > 1 }.keys

        errors.concat duplicates.map { |name| "ambiguous argument #{name} on field #{field.name}" }
      end

      def validate_selection_presence(errors)
        errors << "selection on field #{field.name} can't be empty" if subselection_must_not_be_empty? && empty_selection?
        errors << "selection on field #{field.name} must be empty" if subselection_must_be_empty? && !empty_selection?
      end

      def empty_selection?
        field.selection.empty?
      end

      # @return [Boolean] is field defined on schema?
      def field_defined?
        !field_schema.nil?
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
        field_schema.type.kind == :SCALAR
      end

      def enum?
        field_schema.type.kind == :ENUM
      end

      def interface?
        field_schema.type.kind == :INTERFACE
      end

      def union?
        field_schema.type.kind == :UNION
      end

      def object?
        field_schema.type.kind == :OBJECT
      end
    end
  end
end