# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'
require_relative './collect_variable_references'
require_relative './with_variables'

module Graphlyte
  module Editors
    # Subclass of the full variable inference editor that runs
    # solely on static information (no knowledge of variable
    # runtime values or the exact selected operation).
    #
    # The main difference is that we are more lenient about raising.
    class InferSignature < WithVariables
      def initialize(schema = nil)
        super(schema, nil, nil)
      end

      def select_operation(_doc)
        # no-op
      end

      # We should *always* be able to infer if there is a schema
      # But if we are in dynamic mode, defer inferrence errors until
      # we have runtime values (see `WithVariables`)
      def cannot_infer!(ref)
        super if @schema
      end

      def runtime_type_of(_ref)
        # no-op
      end
    end
  end
end
