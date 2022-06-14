# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      class Arguments
        using Refinements::StringRefinement

        attr_reader :schema, :args

        def initialize(schema)
          @schema = schema
          @args = []
        end

        def <<(with_context)
          @args << with_context
        end

        def validate(errors)
          args.each { |arg| validate_arg(arg, errors) }
        end

        def validate_arg(arg, errors)
          schema_arg(arg)
        end

        def schema_arg(arg, path: path(arg), result: nil)
          return result if path.empty?
          schema_path = path.shift

          result = case schema_path
                   when Syntax::Operation
                     schema.types[schema_path.type.camelize_upper]
                   when Syntax::Field
                     result.fields[schema_path.name]
                   when Syntax::Argument
                     result.arguments[schema_path.name]
                   end

          schema_arg(arg, path: path, result: result)
        end

        def path(arg)
          arg.context.path.dup
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
end
