# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      class Value
        attr_reader :schema, :value

        TYPE_MAP = {
          'ID' => ->(v) { v.integer? || v.type == :STRING },
          'Int' => ->(v) { v.integer? },
          'String' => ->(v) { v.type == :STRING },
          'Boolean' => ->(v) { v.type == :BOOL }
        }

        DEFAULT = ->(type, v) { v.type === type.to_sym }

        def initialize(schema, value_with_context)
          @schema = schema
          @value = value_with_context
        end

        def annotate
          validate_type
        end

        def validate_type
          defn = value.type_definition(schema)

          valid = TYPE_MAP[defn.name]&.call(value.subject) || DEFAULT[defn.name, value.subject]
          value.subject.errors << "value #{value.subject.value} must be of #{defn.name} - got #{value.subject.type}" unless valid
        end
      end
    end
  end
end