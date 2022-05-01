
# frozen_string_literal: true

require_relative '../editor'

module Graphlyte
  module Editors
    class InlineFragments
      FragmentNotFound = Class.new(StandardError)

      def edit(doc)
        inliner.edit(doc)
        defragmenter.edit(doc)
      end

      private

      def inliner
        @inliner ||= Editor.new.on_fragment_spread do |spread, action|
          binding.pry unless spread.name.is_a?(String)
          fragment = action.document.fragments[spread.name]
          raise FragmentNotFound, spread.name unless fragment

          action.replace fragment.inline
        end
      end

      def defragmenter
        @defragmenter ||= Editor.new.on_fragment_definition do |_, action|
          action.delete
        end
      end
    end
  end
end
