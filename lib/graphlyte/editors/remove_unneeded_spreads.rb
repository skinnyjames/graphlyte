# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'
require_relative './annotate_types'

module Graphlyte
  module Editors
    # Remove unnecessary spreads.
    #
    # For example in the query:
    #
    # ```
    # query {
    #   User(id: 1) {
    #     ... on User {
    #       name
    #     }
    #   }
    # }
    # ```
    #
    # If the `Query.User` field has the type `User` then the spread `... on User` is
    # tautological, and we can replace this with:
    #
    # ```
    # query {
    #   User(id: 1) {
    #     name
    #   }
    # }
    # ```
    class RemoveUnneededSpreads
      def initialize(schema = nil)
        @schema = schema
      end

      def edit(doc)
        AnnotateTypes.new(@schema).edit(doc)

        inliner.edit(doc)
      end

      def inliner
        @inliner ||= Editor.top_down.on_inline_fragment do |frag, action|
          action.expand(frag.selection) if inlinable?(frag, action.parent)
        end
      end

      def inlinable?(fragment, parent)
        fragment.directives.none? && type_of(parent) == fragment.type_name
      end

      def type_of(node)
        case node
        when Syntax::Field
          node.type&.inner
        when Syntax::InlineFragment
          node.type_name
        end
      end
    end
  end
end
