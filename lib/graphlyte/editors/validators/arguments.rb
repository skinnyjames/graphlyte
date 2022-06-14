# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # arguments validator
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
          validate_dupes(errors)

          args.each { |arg| validate_arg(arg, errors) }
        end

        def validate_dupes(errors)
          errors.concat(WithGroups.new(args.map(&:subject)).duplicates(:name).map do |name|
                          "ambiguous argument #{name} on field #{args.first.parent_name}"
                        end)
        end

        def validate_arg(arg, errors)
          return if present_if_required?(arg)

          errors << "argument #{arg.subject.name} on field #{arg.context.parent.name} is required"
        end

        def non_null?(arg)
          arg.definition(schema).type.kind == :NON_NULL
        end

        def default_value(arg)
          arg.definition(schema).default_value
        end

        def present_if_required?(arg)
          if non_null?(arg) && default_value(arg).nil?
            !arg.subject.nil? && arg.subject.value.type != :NULL
          else
            true
          end
        end
      end
    end
  end
end
