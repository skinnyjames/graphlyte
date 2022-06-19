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
          defn = inline.type_definition(schema)
          type = inline.subject.type_name

          validate_scope(defn)
          validate_inline_target(type)
          return if valid_fragment_type?(type)

          inline.subject.errors << "inline target #{type} must be kind of UNION, INTERFACE, or OBJECT"
        end

        def validate_scope(defn)
          inline.subject.errors << "#{inline.subject.type_name} is not defined on #{inline.parent_name}" unless defn
        end

        def validate_inline_target(type)
          inline.subject.errors << "inline target #{type} not found" unless schema.types[type]
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
