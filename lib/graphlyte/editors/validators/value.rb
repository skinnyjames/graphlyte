# frozen_string_literal: true

module Graphlyte
  module Editors
    module Validators
      # Validation rules for values
      class Value
        attr_reader :schema, :value

        TYPE_MAP = {
          'ID' => ->(v) { v.integer? || v.type == :STRING },
          'Int' => ->(v) { v.integer? },
          'String' => ->(v) { v.type == :STRING },
          'Boolean' => ->(v) { v.type == :BOOL }
        }.freeze

        DEFAULT = ->(type, v) { v.type == type.to_sym }

        def initialize(schema, value_with_context)
          @schema = schema
          @value = value_with_context
        end

        def annotate
          validate_type
        end

        def validate_type
          defn = value.type_definition(schema)
          return value.subject.errors << "value #{value.subject.value} is invalid - no type" unless defn

          valid = TYPE_MAP[defn.unpack]&.call(value.subject) || DEFAULT[defn.unpack, value.subject]
          return if valid

          value.subject.errors << "value #{value.subject.value} must be of #{defn.unpack} - got #{value.subject.type}"
        end
      end
    end
  end
end
