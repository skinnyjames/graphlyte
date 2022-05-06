# frozen_string_literal: true

require_relative './data'

module Graphlyte
  class Schema < Graphlyte::Data
    class Directive < Graphlyte::Data
      attr_accessor :description, :name
      attr_reader :arguments

      def initialize
        @arguments = {}
      end

      def self.from_schema_response(data)
        dir = new

        dir.name = data['name']
        dir.description = data['description']

        data['arguments']&.each do |arg_data|
          dir.arguments[arg_data['name']] = InputValue.from_schema_response(arg_data)
        end

        dir
      end
    end

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

    class Enum < Graphlyte::Data
      attr_accessor :name, :description, :is_deprecated, :deprecation_reason

      def self.from_schema_response(data)
        new(**data)
      end
    end

    class Type < Graphlyte::Data
      attr_accessor :kind, :name, :description
      attr_reader :fields, :input_fields, :interfaces, :enums, :possible_types

      def initialize
        @fields = {}
        @input_fields = {}
        @interfaces = []
        @enums = {}
        @possible_types = []
      end

      def self.from_schema_response(data)
        type = new
        type.kind = data['kind'].to_sym
        type.name = data['name']
        type.description = data['description']

        data['fields']&.each do |field_data|
          type.fields[field_data['name']] = Field.from_schema_response(field_data)
        end

        data['inputFields']&.each do |field_data|
          type.input_fields[field_data['name']] = InputValue.from_schema_response(field_data)
        end

        data['interfaces']&.each do |d|
          type.interfaces << TypeRef.from_schema_response(d)
        end

        data['enumValues']&.each do |enum_data|
          type.enums[enum_data['name']] = Enum.from_schema_response(enum_data)
        end

        data['possibleTypes']&.each do |type_ref_data|
          type.possible_types << TypeRef.from_schema_response(type_ref_data)
        end

        type
      end
    end

    class Field < Graphlyte::Data
      attr_accessor :name, :description, :type, :is_deprecated, :deprecation_reason
      attr_reader :arguments

      def initialize
        @arguments = {}
      end

      def self.from_schema_response(data)
        field = new

        field.name = data['name']
        field.description = data['description']
        field.type = TypeRef.from_schema_response(data['type'])
        field.is_deprecated = data['isDeprecated']
        field.deprecation_reason = data['deprecationReason']

        if data['arguments']
          data['arguments'].each do |arg_data|
            field.arguments[arg_data['name']] = InputValue.from_schema_response(arg_data)
          end
        end

        field
      end
    end

    attr_accessor :query_type, :mutation_type, :subscription_type
    attr_reader :types, :directives

    def initialize
      @types = {}
      @directives = {}
    end

    def self.from_schema_response(response)
      data = response.dig('data', '__schema')
      raise Argument, 'No data' unless data

      schema = Schema.new

      schema.query_type = data.dig('queryType', 'name')
      schema.mutation_type = data.dig('queryType', 'name')
      schema.subscription_type = data.dig('subscriptionType', 'name')

      data['types'].each do |type_data|
        schema.types[type_data['name']] = Type.from_schema_response(type_data)
      end

      data['directives'].each do |directive_data|
        schema.directives[directive_data['name']] = Directive.from_schema_response(directive_data)
      end

      schema
    end
  end
end
