# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # annotates Syntax::InlineFragment with errors
      class InlineFragment
        attr_reader :schema, :inline

        def initialize(schema, inline)
          @schema = schema
          @inline = inline
        end

        def annotate
          type = inline.subject.type_name
          inline.subject.errors << "inline target #{type} not found" unless schema.types[type]
          return if valid_fragment_type?(type)

          inline.subject.errors << "inline target #{type} must be kind of UNION, INTERFACE, or OBJECT"
        end

        def valid_fragment_type?(type_name)
          %i[UNION INTERFACE OBJECT].reduce(false) do |memo, type|
            schema.types[type_name]&.kind == type || memo
          end
        end
      end
    end
  end
end
