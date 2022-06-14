# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # fragment validator
      class FragmentBehaviors
        attr_reader :schema, :fragments, :spreads, :inline

        def initialize(schema)
          @schema = schema
          @fragments = []
          @spreads = []
          @inline = []
        end

        def add_fragment(fragment)
          fragments << fragment
        end

        def add_spread(spread)
          spreads << spread
        end

        def add_inline(frag)
          inline << frag
        end

        def validate(errors)
          validate_circular_refs(errors)
          validate_unused(errors)
          validate_inline(errors)
          validate_spreads(errors)
          validate_duplicates(errors)
        end

        private

        def fragment_subjects
          fragments.map(&:subject).clone
        end

        def spread_subjects
          spreads.map(&:subject).clone
        end

        def inline_subjects
          inline.map(&:subject)
        end

        def grouped_fragment_subjects
          @grouped_fragment_subjects ||= fragment_subjects.group_by(&:name)
        end

        def validate_duplicates(errors)
          dups = WithGroups.new(fragment_subjects).duplicates(:name)
          errors.concat(dups.map { |frag| "ambiguous fragment name #{frag}" })
        end

        def validate_circular_refs(errors)
          errors.concat(detect_fragment_cycles(fragment_subjects).map do |name|
                          "fragment spread #{name} cannot be circular"
                        end)
        end

        def validate_unused(errors)
          unused_errors = unused(fragment_subjects, spread_subjects).map do |fragment|
            "fragment #{fragment.name} on #{fragment.type_name} must be used in document"
          end
          errors.concat(unused_errors)
        end

        def validate_inline(errors)
          inline_subjects.each do |inline|
            type = inline.type_name

            errors << "inline target #{type} not found" unless schema.types[type]
            unless valid_fragment_type?(inline)
              errors << "inline target #{type} must be kind of UNION, INTERFACE, or OBJECT"
            end
          end
        end

        def validate_spreads(errors)
          consolidated(spread_subjects).each do |hash|
            type = hash[:ref].type_name

            errors << "#{hash[:name]} target #{type} not found" unless schema.types[type]
            unless valid_fragment_type?(hash[:ref])
              errors << "#{hash[:name]} target #{type} must be kind of UNION, INTERFACE, or OBJECT"
            end
          end
        end

        def valid_fragment_type?(fragment)
          %i[UNION INTERFACE OBJECT].reduce(false) do |memo, type|
            schema.types[fragment.type_name]&.kind == type || memo
          end
        end

        def consolidated(spreads, results = [])
          return results if spreads.empty?

          spread = spreads.shift
          ref = grouped_fragment_subjects[spread.name][0]

          results << { name: spread.name, ref: ref }

          consolidated(spreads, results)
        end

        #####
        # Methods to validate unused fragments
        ####
        def unused(fragments, spreads, results = [])
          return results if fragments.empty?

          fragment = fragments.shift
          results << fragment unless spreads.include?(fragment.name)

          unused(fragments, spreads, results)
        end

        #####
        # Methods to validate circular spreads
        #####
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

            next_fragment_definition = fragments.find { |f| f.name == spread }

            detect_fragment_cycle(next_fragment_definition, results, visited: visited, fragments: fragments)
          end
        end

        def get_spread_descendants(fields, results = [])
          return results if fields.empty?

          fields.each do |field|
            if field.instance_of?(Syntax::FragmentSpread)
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
end
