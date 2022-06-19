# frozen_string_literal: true

require_relative './data'
require_relative './refinements/string_refinement'
module Graphlyte
  # Represents a schema definition, containing all type definitions available in a server
  # Reflects the response to a [schema query](./schema_query.rb)
  class Schema < Graphlyte::Data
    using Refinements::StringRefinement

    # A directive adds metadata to a defintion.
    # See: https://spec.graphql.org/October2021/#sec-Language.Directives
    class Directive < Graphlyte::Data
      attr_accessor :description, :name, :arguments

      def initialize(**)
        super

        @arguments ||= {}
      end

      def self.from_schema_response(data)
        new(
          name: data['name'],
          description: data['description'],
          arguments: Schema.entity_map(InputValue, data['args'])
        )
      end
    end

    # An input value defines the values of arguments and the fields of input objects.
    class InputValue < Graphlyte::Data
      attr_accessor :name, :description, :type, :default_value

      def self.from_schema_response(data)
        value = new

        value.name = data['name']
        value.description = data['description']
        value.default_value = data['defaultValue']
        value.type = TypeRef.from_schema_response(data['type'])

        value
      end
    end

    # A type ref names a run-time type
    # See `Type` for the full type definition.
    class TypeRef < Graphlyte::Data
      attr_accessor :kind, :name, :of_type

      def self.from_schema_response(data)
        return unless data

        ref = new

        ref.name = data['name']
        ref.kind = data['kind'].to_sym
        ref.of_type = TypeRef.from_schema_response(data['ofType'])

        ref
      end

      def unpack
        return of_type.unpack if of_type

        name
      end
    end

    # The description of an enum member
    class Enum < Graphlyte::Data
      attr_accessor :name, :description, :is_deprecated, :deprecation_reason

      def self.from_schema_response(data)
        new(**data)
      end
    end

    # A full type definition.
    class Type < Graphlyte::Data
      attr_accessor :kind, :name, :description, :fields, :input_fields, :interfaces, :enums, :possible_types

      def initialize(**)
        super
        @fields ||= {}
        @input_fields ||= {}
        @interfaces ||= []
        @enums ||= {}
        @possible_types ||= []
      end

      def self.from_schema_response(data)
        new(
          kind: data['kind'].to_sym,
          name: data['name'],
          description: data['description'],
          fields: Schema.entity_map(Field, data['fields']),
          input_fields: Schema.entity_map(InputValue, data['inputFields']),
          enums: Schema.entity_map(Enum, data['enumValues']),
          interfaces: Schema.entity_list(TypeRef, data['interfaces']),
          possible_types: Schema.entity_list(TypeRef, data['possibleTypes'])
        )
      end
    end

    # A field definition
    class Field < Graphlyte::Data
      attr_accessor :name, :description, :type, :is_deprecated, :deprecation_reason, :arguments

      def initialize(**)
        super

        @arguments ||= {}
      end

      def self.from_schema_response(data)
        new(
          name: data['name'],
          description: data['description'],
          type: TypeRef.from_schema_response(data['type']),
          is_deprecated: data['isDeprecated'],
          deprecation_reason: data['deprecationReason'],
          arguments: Schema.entity_map(InputValue, data['args'])
        )
      end
    end

    attr_accessor :query_type, :mutation_type, :subscription_type, :types, :directives

    def initialize(**)
      super

      @types ||= {}
      @directives ||= {}
    end

    def self.from_schema_response(response)
      data = response.dig('data', '__schema')
      raise ArgumentError, 'No data' unless data

      new(
        query_type: data.dig('queryType', 'name'),
        mutation_type: data.dig('queryType', 'name'),
        subscription_type: data.dig('subscriptionType', 'name'),
        types: entity_map(Type, data['types']),
        directives: entity_map(Directive, data['directives'])
      )
    end

    def self.entity_list(entity, resp)
      return unless resp

      resp.map { entity.from_schema_response(_1) }
    end

    def self.entity_map(entity, resp)
      return unless resp

      resp.to_h { |entry| [entry['name'], entity.from_schema_response(entry)] }
    end

    def type_definition(path)
      type(definition(path))
    end

    def type(defn)
      defn.instance_of?(Schema::Type) ? defn : defn&.type
    end

    def definition(path = [], result: nil)
      return result if path.empty?

      syntax = path.shift
      result = case syntax
               when Syntax::Operation
                 types[syntax.type.camelize_upper]
               when Syntax::Fragment
                 resolve_fragment_schema(result, syntax)
               when Syntax::InlineFragment
                 if result.name == syntax.type_name
                   result
                 else
                   result.fields[syntax.type_name]
                 end
               when Syntax::FragmentSpread
                 result.fields[syntax.type.unpack]
               when Syntax::Field
                 resolve_field_schema(result, syntax)
               when Syntax::Argument
                 # TODO: handle complex input objects
                 result.arguments[syntax.name]
               when Syntax::InputObject
                 types[result.type.unpack]
               when Syntax::InputObjectArgument
                 result.input_fields[syntax.name]
               when Syntax::Value
                 if result.instance_of?(Schema::InputValue)
                   result
                 else
                   types[result.type.unpack]
                 end
               end
      return nil unless result

      definition(path, result: result)
    end

    private

    def resolve_fragment_schema(result, syntax)
      # for a fragment that is spread on a model
      return result if result&.name == syntax.type_name

      # for a fragment spread on a field
      if result.instance_of?(Schema::Field)
        field_def = types[result.type.unpack]

        return field_def
      end


      result ? result.fields[syntax.type_name] : types[syntax.type_name]
    end

    def resolve_field_schema(result, syntax)
      return types['__Schema'] if syntax.name == '__schema' && result.name == 'Query'

      if result.instance_of?(Schema::Field)
        field_def = types[result.type.unpack]&.fields&.dig(syntax.name)

        return field_def
      end

      result.fields[syntax.name]
    end
  end
end
