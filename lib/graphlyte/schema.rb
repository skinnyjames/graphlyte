
module Graphlyte
  module Schema
    def schema_query
      type_ref_fragment = Graphlyte.fragment('TypeRef', '__Type') do
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

      input_value_fragment = Graphlyte.fragment('InputValues', '__InputValue') do
        name
        description
        type type_ref_fragment
        default_value
      end

      full_type_fragment = Graphlyte.fragment('FullType', '__Type') do
        kind
        name
        description
        fields(includeDeprecated: true) do
          name
          description
          args input_value_fragment
          type type_ref_fragment
          is_deprecated
          deprecation_reason
        end
        input_fields input_value_fragment
        interfaces type_ref_fragment
        enum_values(includeDeprecated: true) do
          name
          description
          is_deprecated
          deprecation_reason
        end
        possible_types type_ref_fragment
      end

      Graphlyte.query do
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
