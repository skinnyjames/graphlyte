# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # Responsible for validating the properties
      # of the document object and the constructs that live
      # directly underneath it (Fragments and Operations)
      class Document
        attr_reader :schema, :doc

        def initialize(schema, document)
          @schema = schema
          @doc = document
        end

        def annotate
          validate_mixed_operation_types
        end

        def validate_mixed_operation_types
          keys = with_groups.groups(:name).keys
          doc.errors << 'cannot mix anonymous and named operations' if keys.size > 1 && keys.include?(nil)
        end

        def with_groups
          WithGroups.new(doc.operations.values)
        end

        ### fragment behavior validation
        def fragment_collector; end
      end
    end
  end
end
