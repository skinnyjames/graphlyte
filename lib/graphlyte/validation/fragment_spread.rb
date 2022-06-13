# frozen_string_literal: true

require_relative '../editors/collect_fragment_spreads'

module Graphlyte
  module Validation
    FragmentSpreads = Struct.new(:schema, :spreads) do
      def self.from_document(schema, document, spreads: Editors::CollectFragmentSpreads.new.edit(document))
        new(schema, spreads)
      end

      def validate(errors)
        validate_spreads(spreads[:spreads], errors)
        validate_inline(spreads[:inline], errors)
        validate_unused(spreads[:unused], errors)
        validate_cyclomatic(spreads[:cyclomatic], errors)
      end

      private

      def validate_spreads(fragment_spreads, errors)
        fragment_spreads.each do |hash|
          type = hash[:ref].type_name

          errors << "#{hash[:name]} target #{type} not found" unless schema.types[type]
          errors << "#{hash[:name]} target #{type} must be kind of UNION, INTERFACE, or OBJECT" unless validate_fragment_type(hash[:ref])
        end
      end

      def validate_inline(spreads, errors)
        spreads.each do |inline|
          type = inline[:fragment].type_name

          errors << "inline target #{type} not found" unless schema.types[type]
          errors << "inline target #{type} must be kind of UNION, INTERFACE, or OBJECT" unless validate_fragment_type(inline[:fragment])
        end
      end

      def validate_unused(fragments, errors)
        fragments.each do |fragment|
          errors << "fragment #{fragment.name} on #{fragment.type_name} must be used in document"
        end
      end

      def validate_cyclomatic(spreads, errors)
        spreads.each do |spread|
          errors << "fragment spread #{spread} cannot be cyclomatic"
        end
      end

      def validate_fragment_type(fragment)
        [:UNION, :INTERFACE, :OBJECT].reduce(false) do |memo, type|
          schema.types[fragment.type_name]&.kind == type || memo
        end
      end
    end
  end
end
