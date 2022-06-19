# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # annotates Syntax::FragmentSpread with errors
      class FragmentSpread
        attr_reader :schema, :spread, :fragments

        def initialize(schema, spread, fragments)
          @schema = schema
          @spread = spread
          @fragments = fragments
        end

        def annotate
          fragment = matching_fragment

          spread.subject.errors << 'has no matching fragment' unless matching_fragment
          spread.subject.errors << "target #{fragment.type_name} not found" unless schema.types[fragment.type_name]
          return if valid_fragment_type?(fragment)

          spread.subject.errors << "target #{fragment.type_name} must be kind of UNION, INTERFACE, or OBJECT"
        end

        def scope_valid?

        end

        def matching_fragment
          grouped_fragment_subjects[spread.subject.name]
        end

        def grouped_fragment_subjects
          @grouped_fragment_subjects ||= fragment_subjects.to_h { [_1.name, _1] }
        end

        def fragment_subjects
          fragments.map(&:subject)
        end

        def valid_fragment_type?(fragment)
          %i[UNION INTERFACE OBJECT].reduce(false) do |memo, type|
            schema.types[fragment.type_name]&.kind == type || memo
          end
        end
      end
    end
  end
end
