# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      class Argument
        attr_reader :schema, :arg

        def initialize(schema, arg_with_context)
          @schema = schema
          @arg = arg_with_context
        end

        def annotate
          defn = arg.type_definition(schema)
          return unless defn.nil?

          arg.subject.errors << "Argument #{arg.subject.name} not defined on #{arg.context.parent.name}"
        end
      end
    end
  end
end