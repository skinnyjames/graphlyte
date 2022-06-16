# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # Field level validator
      # Annotates Syntax::Field objects with errors
      class Field
        attr_reader :schema, :field

        def initialize(schema, field_with_context)
          @schema = schema
          @field = field_with_context
        end

        def annotate
          unless valid_type?
            field.subject.errors << "field #{field.subject.name} is not defined on #{field.parent_name}"
            return
          end

          validate_duplicate_arguments
          validate_required_arguments
          validate_selection
        end

        def validate_duplicate_arguments
          dupes = WithGroups.new(field.subject.arguments).duplicates(:name)
          field.subject.errors << "has ambiguous args: #{dupes.join(', ')}" if dupes.any?
        end

        def validate_required_arguments
          definition.respond_to?(:arguments) && definition.arguments.each do |name, input_value|
            arg_or_nil = field.subject.arguments.find { |arg| arg.name == name }

            field.subject.errors << "argument #{name} on field #{field.subject.name} is required" unless required_arg?(
              input_value, arg_or_nil
            )
          end
        end

        def validate_selection
          if subselection_must_be_empty? && !field.subject.selection.empty?
            field.subject.errors << "selection on field #{field.subject.name} must be empty"
          elsif subselection_must_not_be_empty? && field.subject.selection.empty?
            field.subject.errors << "selection on field #{field.subject.name} can't be empty"
          end
        end

        def valid_type?
          !definition.nil?
        end

        def definition
          field.definition(schema)
        end

        def type_definition
          field.type_definition(schema)
        end

        def required_arg?(input_value, arg_or_nil)
          if input_value.type.kind == :NON_NULL && input_value.default_value.nil?
            !arg_or_nil.nil? && arg_or_nil.value.type != :NULL
          else
            true
          end
        end

        def subselection_must_be_empty?
          %i[SCALAR ENUM].include?(type_definition.kind)
        end

        def subselection_must_not_be_empty?
          %i[INTERFACE UNION OBJECT].include?(type_definition.kind)
        end
      end
    end
  end
end
