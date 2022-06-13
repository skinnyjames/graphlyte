# frazen_string_literal: true

module Graphlyte
  module Editors
    class CollectFragmentSpreads

      def edit(doc)
        editor.edit(doc)

        # todo: consolidate inline fragments
        {
          spreads: consolidate(@fragment_spreads.dup, @fragments.dup),
          unused: unused_fragments(@fragments.dup, @fragment_spreads.dup),
          inline: @inline_fragments,
          cyclomatic: detect_fragment_cycles(@fragments.dup)
        }
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
          .on_fragment_spread { |spread, action| @fragment_spreads << spread.name }
      end

      def consolidate(spreads, fragments, results = [])
        return results if spreads.empty?
        spread = spreads.shift
        ref = fragments.find { |frag| frag.name == spread }

        results << { name: spread, ref: ref }

        consolidate(spreads, fragments, results)
      end

      def detect_fragment_cycles(fragments, results = [])
        fragments.each do |fragment|
          detect_fragment_cycle(fragment, results, fragments: fragments)
        end
        results
      end

        def detect_fragment_cycle(fragment_definition, results, visited: [], fragments: nil)
          nested_spreads = get_spread_descendants(fragment_definition.selection)
          nested_spreads.each do |spread|
            if visited.include?(spread)
              results << spread
              break
            end
            visited << spread

            next_fragment_definition = fragments.find {|f| f.name == spread }

            detect_fragment_cycle(next_fragment_definition, results, visited: visited, fragments: fragments)
          end
        end

      def unused_fragments(fragments, spreads, results = [])
        return results if fragments.empty?

        fragment = fragments.shift
        results << fragment unless spreads.include?(fragment.name)

        unused_fragments(fragments, spreads, results)
      end

      def get_duplicates(spread_array)
        spread_array.each_with_object({}) do |spread, memo|
          memo[spread] = (memo[spread] || 0) + 1
        end
          .select { |k, v| v > 1 }.keys
      end

      def get_spread_descendants(fields, results = [])
        return results if fields.empty?

        fields.each do |field|
          if field.class == Syntax::FragmentSpread
            results << field.name
          else
            get_spread_descendants(field.selection, results)
          end
        end

        results
      end
    end
  end
end