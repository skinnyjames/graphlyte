# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      class InputObject
        attr_reader :schema, :input_object

        def initialize(schema, input_object_with_context)
          @schema = schema
          @input_object = input_object_with_context
        end

        def annotate
          defn = input_object.type_definition(schema)
          return if defn.nil?

          validate_field_names(defn)
          validate_unique
          validate_required(defn)
        end

        def validate_field_names(defn)

          values.each do |io_arg|
            input_object.subject.errors << "Input object field #{io_arg.name} does not exist on #{defn.name}" unless defn.input_fields[io_arg.name]
          end
        end

        def validate_required(defn)
          defn.input_fields.each { |k, v| check_required(k, v) }
        end

        # todo: the parser wont allow this state to happen
        def validate_unique
          WithGroups.new(values).duplicates(:name).each do |dup|
            input_object.subject.errors << "Duplicate key #{dup} detected"
          end
        end

        private

        def grouped
          input_object.subject.values.to_h { |obj| [obj.name, obj.value ] }
        end

        def check_required(name, input_value, arg_or_nil: grouped[name])
          if input_value.type.kind == :NON_NULL && input_value.default_value.nil?
            if arg_or_nil.nil? || arg_or_nil.value.type == :NULL
              input_object.subject.errors << "argument #{name} is required"
            end
          end
        end

        def values
          input_object.subject.values
        end
      end
    end
  end
end