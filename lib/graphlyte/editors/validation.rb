# frozen_string_literal: true

require_relative './validators/operations'
require_relative './validators/fragment_behaviors'
require_relative './validators/arguments'
require_relative './validators/fields'

module Graphlyte
  module Editors
    # context helpers
    module ContextHelpers
      using Refinements::StringRefinement

      def definition(schema, path: context.path.dup, result: nil)
        return result if path.empty?

        schema_path = path.shift

        result = case schema_path
                 when Syntax::Operation
                   schema.types[schema_path.type.camelize_upper]
                 when Syntax::Field
                   resolve_field_schema(result, schema_path, schema: schema, rest: path.size)
                 when Syntax::Argument
                   result.arguments[schema_path.name]
                 end

        return nil unless result

        definition(schema, path: path, result: result)
      end

      def parent_name
        case context.parent
        when Syntax::InlineFragment, Syntax::Fragment
          context.parent.type_name
        else
          context.parent.name
        end
      end

      def resolve_field_schema(result, field, schema:, rest:)
        if result.is_a?(Schema::Field)
          schema_field = schema.types[result.name]&.fields&.dig(field.name) if result.type.kind == :OBJECT

          return nil if schema_field.nil?

          return schema_field.type.kind == :LIST && !rest.zero? ? schema.types[schema_field.type.unpack] : schema_field
        end

        result.fields[field.name]
      end
    end

    WithContext = Struct.new(:subject, :context) do
      using Refinements::StringRefinement
      include ContextHelpers
    end

    WithGroups = Struct.new(:collection) do
      def groups(group_by)
        collection.each_with_object({}) do |item, memo|
          memo[item.send(group_by)] = (memo[item.send(group_by)] || 0) + 1
        end
      end

      def duplicates(group_by)
        groups(group_by)
          .filter_map { |k, v| k if v > 1 }
      end
    end

    # Validation editor
    class Validation
      attr_reader(
        :schema,
        :operations,
        :fragment_behaviors,
        :fields,
        :arguments,
        :variables
      )

      def initialize(schema)
        @schema = schema
        @operations = Validators::Operations.new(schema)
        @fragment_behaviors = Validators::FragmentBehaviors.new(schema)
        @fields = Validators::Fields.new(schema)
        @arguments = Validators::Arguments.new(schema)
        @variables = []
      end

      def edit(document)
        editor.edit(document)

        self
      end

      def validate(errors = [])
        operations.validate(errors)
        fragment_behaviors.validate(errors)
        fields.validate(errors)
        arguments.validate(errors)

        raise Invalid.new(*errors) unless errors.empty?
      end

      def editor
        Editor
          .top_down
          .on_fragment_spread(&method(:collect_fragment_spread))
          .on_fragment(&method(:collect_fragment))
          .on_operation(&method(:collect_operation))
          .on_field(&method(:collect_field))
          .on_argument(&method(:collect_argument))
          .on_variable(&method(:collect_variable))
      end

      def collect_fragment_spread(spread, action, with_context: WithContext.new(spread, action))
        fragment_behaviors.add_spread(with_context)
      end

      def collect_fragment(fragment, action, with_context: WithContext.new(fragment, action))
        if fragment.instance_of?(Syntax::InlineFragment)
          fragment_behaviors.add_inline(with_context)
        else
          fragment_behaviors.add_fragment(with_context)
        end
      end

      def collect_operation(operation, action, with_context: WithContext.new(operation, action))
        operations << with_context
      end

      def collect_field(field, action)
        fields << WithContext.new(field, action)
      end

      def collect_argument(arg, action, with_context: WithContext.new(arg, action))
        arguments << with_context
      end

      def collect_variable(var, action); end
    end
  end
end
