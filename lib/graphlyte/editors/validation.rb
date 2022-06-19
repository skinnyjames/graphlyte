# frozen_string_literal: true

require_relative './validators/operation'
require_relative './validators/fragment'
require_relative './validators/document'
require_relative './validators/field'
require_relative './validators/fragment_spread'
require_relative './validators/inline_fragment'
require_relative './validators/input_object'
require_relative './validators/argument'

module Graphlyte
  module Editors
    # context helpers
    module ContextHelpers
      using Refinements::StringRefinement

      def type_definition(schema)
        defn = definition(schema)
        defn.instance_of?(Schema::Type) ? defn : defn&.type
      end

      # Returns some kind of def for a given Syntax object
      # @return [Schema::Field | Schema::Type] result
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      def definition(schema, path: context.path.dup, result: nil)
        return result if path.empty?

        syntax = path.shift
        result = case syntax
                 when Syntax::Operation
                   schema.types[syntax.type.camelize_upper]
                 when Syntax::Fragment
                   schema.types[syntax.type_name]
                 when Syntax::InlineFragment
                   if result.name == syntax.type_name
                     result
                   else
                    result.fields[syntax.type_name]
                   end
                 when Syntax::FragmentSpread
                   one = :two
                 when Syntax::Field
                   resolve_field_schema(result, syntax, schema: schema)
                 when Syntax::Argument
                   # TODO: handle complex input objects
                   result.arguments[syntax.name]
                 when Syntax::InputObject
                   schema.types[result.type.unpack]
                 when Syntax::InputObjectArgument
                   result.input_fields[syntax.name]
                 when Syntax::Value
                   if result.instance_of?(Schema::InputValue)
                     result
                   else
                     schema.types[result.type.unpack]
                   end
                 end
        return nil unless result

        definition(schema, path: path || [], result: result)
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity

      def parent_name
        case context.parent
        when Syntax::InlineFragment, Syntax::Fragment
          context.parent.type_name
        else
          context.parent.name
        end
      end

      def resolve_field_schema(result, syntax, schema:)
        return schema.types['__Schema'] if syntax.name == '__schema' && result.name == 'Query'

        if result.instance_of?(Schema::Field)
          field_def = schema.types[result.type.unpack]&.fields&.dig(syntax.name)

          return field_def
        end

        result.fields[syntax.name]
      end
    end

    WithContext = Struct.new(:subject, :context) do
      using Refinements::StringRefinement
      include ContextHelpers
    end

    WithGroups = Struct.new(:items) do
      def groups(group_by)
        items.each_with_object({}) do |item, memo|
          memo[item.send(group_by)] = (memo[item.send(group_by)] || 0) + 1
        end
      end

      def duplicates(group_by)
        groups(group_by)
          .filter_map { |k, v| k if v > 1 }
      end
    end

    # Validation editor
    # Will add schema level errors to the
    # Syntax tree objects
    class Validation
      attr_reader(
        :schema,
        :fragments,
        :spreads,
        :inline
      )

      def initialize(schema)
        @schema = schema
        @spreads = []
        @fragments = []
        @inline = []
      end

      def edit(document)
        Validators::Document.new(schema, document).annotate

        fragment_collector.edit(document)
        editor.edit(document)

        document
      end

      def fragment_collector
        Editor
          .top_down
          .on_fragment_spread(&method(:collect_fragment_spread))
          .on_fragment(&method(:collect_fragment))
      end

      def editor
        Editor
          .top_down
          .on_operation(&method(:validate_operation))
          .on_fragment(&method(:validate_fragment))
          .on_fragment_spread(&method(:validate_fragment_spread))
          .on_field(&method(:validate_field))
          .on_input_object(&method(:validate_input_object))
          .on_argument(&method(:validate_argument))
          .on_value(&method(:validate_value))
          .on_variable(&method(:validate_variable))
      end

      def collect_fragment_spread(spread, action, with_context: WithContext.new(spread, action))
        spreads << with_context
      end

      def collect_fragment(fragment, action, with_context: WithContext.new(fragment, action))
        if fragment.instance_of?(Syntax::InlineFragment)
          inline << with_context
        else
          fragments << with_context
        end
      end

      def validate_fragment(frag, action, with_context: WithContext.new(frag, action))
        if frag.instance_of?(Syntax::InlineFragment)
          Validators::InlineFragment.new(schema, with_context).annotate
        else
          Validators::Fragment.new(schema, with_context, fragments, spreads).annotate
        end
      end

      def validate_fragment_spread(spread, action, with_context: WithContext.new(spread, action))
        Validators::FragmentSpread.new(schema, with_context, fragments).annotate
      end

      def validate_operation(operation, action, with_context: WithContext.new(operation, action))
        Validators::Operation.new(schema, with_context).annotate
      end

      def validate_field(field, action)
        Validators::Field.new(schema, WithContext.new(field, action)).annotate
      end

      def validate_argument(arg, action, with_context: WithContext.new(arg, action))
        Validators::Argument.new(schema, with_context).annotate
      end

      def validate_value(val, action, with_context: WithContext.new(val, action))
        Validators::Value.new(schema, with_context).annotate
      end

      def validate_input_object(input_obj, action, with_context: WithContext.new(input_obj, action))
        Validators::InputObject.new(schema, with_context).annotate
      end

      def validate_variable(var, action); end
    end
  end
end
