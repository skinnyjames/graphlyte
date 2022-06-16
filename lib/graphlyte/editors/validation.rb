# frozen_string_literal: true

require_relative './validators/operation'
require_relative './validators/fragment'
require_relative './validators/document'
require_relative './validators/field'
require_relative './validators/fragment_spread'
require_relative './validators/inline_fragment'

module Graphlyte
  module Editors
    # context helpers
    module ContextHelpers
      using Refinements::StringRefinement

      # given a syntax path, it will return an associated schema object
      # todo: this doesn't work right now
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

      def resolve_field_schema(result, field, schema:, rest:) # rubocop:disable Metrics/AbcSize
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
          .on_argument(&method(:validate_argument))
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

      def validate_argument(arg, action, with_context: WithContext.new(arg, action)); end

      def validate_variable(var, action); end
    end
  end
end
