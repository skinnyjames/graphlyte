# frozen_string_literal: true

require_relative './validators/operations'
require_relative './validators/fragment_behaviors'
require_relative './validators/arguments'

module Graphlyte
  module Editors
    WithContext = Struct.new(:subject, :context)

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
        @fields = []
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
        if fragment.class == Syntax::InlineFragment
          fragment_behaviors.add_inline(with_context)
        else
          fragment_behaviors.add_fragment(with_context)
        end
      end

      def collect_operation(op, action, with_context: WithContext.new(op, action))
        operations << with_context
      end

      def collect_field(field, action)

      end

      def collect_argument(arg, action, with_context: WithContext.new(arg, action))
        arguments << with_context
      end

      def collect_variable(var, action)

      end
    end
  end
end