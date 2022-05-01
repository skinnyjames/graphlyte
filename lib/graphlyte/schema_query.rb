# frozen_string_literal: true

require_relative "./dsl"

module Graphlyte
  module SchemaQuery
    def schema_query
      dsl = DSL.new

      type_ref_fragment = dsl.fragment(on: '__Type') do
        kind
        name
        of_type { 
          kind
          name
          of_type {
            kind
            name
            of_type {
              kind
              name
              of_type {
                kind
                name
                of_type {
                  kind
                  name
                  of_type {
                    kind
                    name
                    of_type {
                      kind
                      name
                    }
                  }
                }
              }
            }
          }
        }
      end

      input_value_fragment = dsl.fragment(on: '__InputValue') do
        name
        description
        type type_ref_fragment
        default_value
      end

      full_type_fragment = dsl.fragment(on: '__Type') do
        kind
        name
        description
        fields(include_deprecated: true) do
          name
          description
          args input_value_fragment
          type type_ref_fragment
          is_deprecated
          deprecation_reason
        end
        input_fields input_value_fragment
        interfaces type_ref_fragment
        enum_values(include_deprecated: true) do
          name
          description
          is_deprecated
          deprecation_reason
        end
        possible_types type_ref_fragment
      end

      dsl.query do
        __schema do
          query_type { name }
          mutation_type { name }
          subscription_type { name }
          types full_type_fragment
          directives do
            name
            description
            args input_value_fragment
          end
        end
      end
    end
  end
end
