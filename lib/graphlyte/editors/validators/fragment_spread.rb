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
          spread.subject.errors << "target #{fragment.subject.type_name} not found" unless schema.types[fragment.subject.type_name]
          validate_scope(fragment)

          return if valid_fragment_type?(fragment.subject)

          spread.subject.errors << "target #{fragment.subject.type_name} must be kind of UNION, INTERFACE, or OBJECT"
        end

        def validate_scope(fragment, parent = spread.context.parent)
          new_path = [*spread.context.path.dup[0..-2], fragment.subject]

          defn = SchemaHelpers.type_definition(schema, path: new_path)
          return unless defn.nil?

          parentdefn = SchemaHelpers.type_definition(schema, path: [spread.context.parent])

          if parentdefn.nil?
            spread.subject.errors << "#{fragment.subject.type_name} target #{spread.parent_name} does not exist"
          else
            spread.subject.errors << "#{fragment.subject.type_name} is not defined on #{parentdefn.name}"
          end
        end

        def parent_type_def

        end

        def matching_fragment
          grouped_fragments[spread.subject.name]
        end

        def grouped_fragments
          @grouped_fragment_subjects ||= fragments.to_h { [_1.subject.name, _1] }
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
