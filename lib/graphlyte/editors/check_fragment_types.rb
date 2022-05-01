# frozen_string_literal: true

module Graphlyte
  module Editors
    class CheckFragmentTypes
      def initialize(schema)
        @schema = schema
      end

      def editor
        e = Editor.new
        e.direction = :top_down

        e.on_fragment_spread do |spread, action|
          fragment = action.document.fragments[spread.name]

          check_compatible(action.parent, fragment.type_name)
        end

        e.on_inline_fragment do |fragment, action|
          check_compatible(action.parent, fragment.type_name)
        end

        e
      end

      def check_compatible(node, type_name)
        # TODO!
      end
    end
  end
end
