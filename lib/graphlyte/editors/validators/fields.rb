# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      class Fields
        attr_reader :schema, :fields

        def initialize(schema)
          @schema = schema
          @fields = []
        end

        def <<(field_with_context)
          fields << field_with_context
        end

        def validate(errors)
          fields.each { |field| validate_field(field, errors) }
        end

        def validate_field(field, errors)
          field_def = field.definition(schema)
          return errors << "#{field.subject.name} is not defined on #{field.parent_name}" unless field_def

          validate_selection(field, errors, definition: field_def)
          validate_required_arguments(field, errors, definition: field_def)
        end

        def validate_required_arguments(field, errors, definition:)
          definition.arguments.each do |name, input_value|
            arg_or_nil = field.subject.arguments.find { |arg| arg.name == name }

            errors << "argument #{name} on field #{field.subject.name} is required" unless has_required_arg(input_value, arg_or_nil)
          end
        end

        def validate_selection(field, errors, definition:)
          if subselection_must_be_empty?(definition) && !field.subject.selection.empty?
            errors << "selection on field #{field.subject.name} must be empty"
          elsif subselection_must_not_be_empty?(definition) && field.subject.selection.empty?
            errors << "selection on field #{field.subject.name} can't be empty"
          end
        end

        def has_required_arg(input_value, arg_or_nil)
          if input_value.type.kind == :NON_NULL && input_value.default_value.nil?
            !arg_or_nil.nil? && arg_or_nil.value.type != :NULL
          else
            true
          end
        end

        def subselection_must_be_empty?(defn)
          [:SCALAR, :ENUM].include?(defn.type.kind)
        end

        # if selectionType is interface, union, or object
        # the subselection must not be empty
        #
        # @return [Boolean] should selection type be populated?
        def subselection_must_not_be_empty?(defn)
          [:INTERFACE, :UNION, :OBJECT].include?(defn.type.kind)
        end
      end
    end
  end
end