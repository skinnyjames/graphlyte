# frozen_string_literal: true

require_relative '../editor'

module Graphlyte
  module Editors
    # Replace all uses of fragment spreads by inlining the fragment. This will
    # increase the size of the document, sometimes by rather a lot.
    #
    # But doing so then makes other analysis (such as variable usage) much simpler.
    class InlineFragments
      FragmentNotFound = Class.new(StandardError)

      def edit(doc)
        inliner.edit(doc)
        defragmenter.edit(doc)
      end

      private

      def inliner
        @inliner ||= Editor.new.on_fragment_spread do |spread, action|
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
