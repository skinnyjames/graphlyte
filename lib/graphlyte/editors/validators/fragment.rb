# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # Fragment Validator
      # annotates Syntax::Fragment objects with errors
      class Fragment
        attr_reader :schema, :fragment, :fragments, :spreads

        def initialize(schema, fragment, fragments, spreads)
          @schema = schema
          @fragment = fragment
          @fragments = fragments
          @spreads = spreads
        end

        def annotate
          if duplicates.include?(fragment.subject.name)
            fragment.subject.errors << "ambiguous name #{fragment.subject.name}"
          end

          circular, path = *circular_references
          fragment.subject.errors << "Circular reference: #{path.join(' > ')}" if circular
          fragment.subject.errors << 'fragment must be used' if unused?
        end

        def duplicates
          WithGroups.new(fragments.map(&:subject)).duplicates(:name)
        end

        def fragments_subjects
          fragments.map(&:subject)
        end

        def unused?
          !spreads.map { |s| s.subject.name }.include?(fragment.subject.name)
        end

        def circular_references(results = [])
          detect_fragment_cycles(fragment.subject, results, fragments: fragments_subjects)
        end

        def detect_fragment_cycles(fragment_definition, results, visited: [fragment.subject.name], fragments: nil)
          get_spread_descendants(fragment_definition.selection).each do |spread|
            if visited.include?(spread)
              results << spread
              visited << spread
              break
            end
            visited << spread

            next_fragment_definition = fragments.find { |f| f.name == spread }

            detect_fragment_cycles(next_fragment_definition, results, visited: visited, fragments: fragments)
          end
          [!results.empty?, visited]
        end

        def get_spread_descendants(fields, results = [])
          return results if fields.empty?

          fields.each do |field|
            if field.instance_of?(Syntax::FragmentSpread)
              results << field.name
            # else
            #   get_spread_descendants(field.selection, results)
            end
          end

          results
        end
      end
    end
  end
end
