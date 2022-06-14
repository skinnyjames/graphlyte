# frozen_string_literal: true

module Graphlyte
  module Validation
    Fragments = Struct.new(:schema, :fragments) do
      include Enumerable

      def validate(errors)
        validate_duplicates(errors)

        each { |frag| frag.validate(errors) }
      end

      def each
        fragments.each do |frag|
          yield Fragment.new(schema, frag)
        end
      end

      private

      def validate_duplicates(errors)
        errors.concat(duplicates.map { |frag| "ambiguous fragment name #{frag}" })
      end

      def duplicates
        results = each_with_object({}) do |frag, memo|
          memo[frag.fragment.name] = (memo[frag.fragment.name] || 0) + 1
        end

        results.select { |_name, count| count > 1 }.keys
      end
    end

    Fragment = Struct.new(:schema, :fragment) do
      def validate(errors)
        # Fields.new(schema, fragment.selection, schema.types['Query']).validate(errors)
      end
    end
  end
end
