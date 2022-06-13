# frozen_string_literal: true

require_relative './operation'
require_relative './fragment'
require_relative './fragment_spread'

module Graphlyte
  module Validation
    Document = Struct.new(:schema) do
      def validate(document, errors: [])
        operations, fragments = *definitions(document)

        Operations.new(schema, operations).validate(errors)
        Fragments.new(schema, fragments).validate(errors)
        FragmentSpreads.from_document(schema, document).validate(errors)

        raise Invalid.new(*errors) if errors.any?
      end

      private

      def definitions(document)
        definitions = [[], []]

        document.definitions.each_with_object(definitions) do |definition, values|
          case definition
          when Syntax::Operation
            values[0] << definition
          when Syntax::Fragment
            values[1] << definition
          end
        end

        definitions
      end
    end
  end
end
