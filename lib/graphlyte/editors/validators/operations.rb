# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # Operations validator
      class Operations
        attr_reader :schema, :operations

        def initialize(schema)
          @schema = schema
          @operations = []
        end

        def <<(with_context)
          @operations << with_context
        end

        def validate(errors)
          validate_duplicates(errors)
          validate_mixed_operation_types(errors)
        end

        # validate that named and anonymous operations
        # cannot be used in the same query
        #
        # @return [Void]
        def validate_mixed_operation_types(errors)
          keys = with_groups.groups(:name).keys
          errors << 'cannot mix anonymous and named operations' if keys.size > 1 && keys.include?(nil)
        end

        # add any duplicate messages to errors
        #
        # @return [Void]
        def validate_duplicates(errors)
          errors.concat(with_groups.duplicates(:name).map { |name| "ambiguous operation name #{name}" })
        end

        def with_groups
          WithGroups.new(operations.map(&:subject))
        end
      end
    end
  end
end
