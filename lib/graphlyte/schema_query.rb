# frozen_string_literal: true

require_relative './dsl'

module Graphlyte
  module SchemaQuery
    def schema_query
      SchemaQuery::Query.new.build
    end

    class Query
      attr_reader :dsl, :doc

      def initialize
        @dsl = DSL.new
        @doc = Graphlyte::Document.new
      end

      def build
        full_type = full_type_fragment
        input_value = input_value_fragment

        @build ||= dsl.query('Schema', doc) do
          __schema do
            query_type { name }
            mutation_type { name }
            subscription_type { name }
            types(full_type)
            directives do
              name
              description
              args(input_value)
            end
          end
        end
      end

      def type_ref_fragment
        @type_ref_fragment ||= dsl.fragment(on: '__Type', doc: doc) do
          depth = 0

          select_type_reference = lambda do |node|
            node.kind
            node.name
            depth += 1
            node.of_type { select_type_reference[self] } if depth < 8
          end

          select_type_reference[self]
        end
      end

      def full_type_fragment
        type_ref = type_ref_fragment
        input_value = input_value_fragment
        fields = fields_fragment
        enums = enums_fragment

        @full_type_fragment ||= dsl.fragment(on: '__Type', doc: doc) do
          kind
          name
          description
          self << fields
          input_fields(input_value)
          interfaces(type_ref)
          self << enums
          possible_types(type_ref)
        end
      end

      def enums_fragment
        @enums_fragment ||= dsl.fragment(on: '__Type', doc: doc) do
          enum_values(include_deprecated: true) do
            name
            description
            is_deprecated
            deprecation_reason
          end
        end
      end

      def fields_fragment
        type_ref = type_ref_fragment
        input_value = input_value_fragment

        @fields_fragment ||= dsl.fragment(on: '__Type', doc: doc) do
          fields(include_deprecated: true) do
            name
            description
            args(input_value)
            type(type_ref)
            is_deprecated
            deprecation_reason
          end
        end
      end

      def input_value_fragment
        type_ref = type_ref_fragment

        @input_value_fragment ||= dsl.fragment(on: '__InputValue', doc: doc) do
          name
          description
          type type_ref
          default_value
        end
      end
    end
  end
end
