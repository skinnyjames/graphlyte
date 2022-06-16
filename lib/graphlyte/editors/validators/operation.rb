# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # annotates Syntax::Operation with errors
      class Operation
        attr_reader :schema, :op

        def initialize(schema, op_with_context)
          @schema = schema
          @op = op_with_context
        end

        def annotate
          validate_duplicates
        end

        def validate_duplicates
          op.subject.errors << "ambiguous operation name #{op.subject.name}" if duplicates.include?(op.subject.name)
        end

        def duplicates
          operations = op.context.document.definitions.select { |d| d.is_a?(Syntax::Operation) }
          WithGroups.new(operations).duplicates(:name)
        end
      end
    end
  end
end
