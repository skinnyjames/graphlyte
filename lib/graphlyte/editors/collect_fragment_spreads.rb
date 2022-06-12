# frazen_string_literal: true

module Graphlyte
  module Editors
    class CollectFragmentSpreads

      def edit(doc)
        editor.edit(doc)

        # todo: consolidate inline fragments
        { spreads: consolidate(@fragment_spreads.dup, @fragments), inline: @inline_fragments }
      end

      def editor
        @fragment_spreads = []
        @inline_fragments = []
        @fragments = []
        Editor
          .new
          .on_fragment do |frag, action|
            if frag.is_a?(Syntax::InlineFragment)
              @inline_fragments << { fragment:  frag, parent: action.parent }
            else
              @fragments << frag
            end
          end
          .on_fragment_spread { |spread| @fragment_spreads << spread.name }
      end

      def consolidate(spreads, fragments, results = [])
        return results if spreads.empty?
        name = spreads.shift
        ref = fragments.find { |frag| frag.name == name }

        results << { name: name, ref: ref }

        consolidate(spreads, fragments, results)
      end
    end
  end
end