# frozen_string_literal: true

require_relative './dsl'

module Graphlyte
  # extend this module to gain access to a schema_query method
  module SchemaQuery
    def schema_query
      SchemaQuery::Query.new.build
    end

    # Builder for a schema query
    class Query
      attr_reader :dsl, :doc

      def initialize
        @dsl = DSL.new
        @doc = Graphlyte::Document.new
      end

      def build
        @build ||= dsl.query('Schema', doc) do |q|
          q.__schema do |s|
            s.query_type(&:name)
            s.mutation_type(&:name)
            s.subscription_type(&:name)
            s.types(full_type_fragment)
            query_directives(s)
          end
        end
      end

      def query_directives(schema)
        schema.directives do |d|
          d.name
          d.description
          d.args(input_value_fragment)
        end
      end

      def type_ref_fragment
        @type_ref_fragment ||= dsl.fragment(on: '__Type', doc: doc) do |t|
          select_type_reference(t)
        end
      end

      def select_type_reference(node, depth: 0)
        node.kind
        node.name
        node.of_type { |child| select_type_reference(child, depth: depth + 1) } if depth < 8
      end

      def full_type_fragment
        @full_type_fragment ||= dsl.fragment(on: '__Type', doc: doc) do |t|
          t.kind
          t.name
          t.description
          t << fields_fragment
          t.input_fields(input_value_fragment)
          t.interfaces(type_ref_fragment)
          t << enums_fragment
          t.possible_types(type_ref_fragment)
        end
      end

      def enums_fragment
        @enums_fragment ||= dsl.fragment(on: '__Type', doc: doc) do |t|
          t.enum_values(include_deprecated: true) do |e|
            e.name
            e.description
            e.is_deprecated
            e.deprecation_reason
          end
        end
      end

      def fields_fragment
        @fields_fragment ||= dsl.fragment(on: '__Type', doc: doc) do |t|
          t.fields(include_deprecated: true) do |f|
            f.name
            f.description
            f.args(input_value_fragment)
            f.type(type_ref_fragment)
            f.is_deprecated
            f.deprecation_reason
          end
        end
      end

      def input_value_fragment
        @input_value_fragment ||= dsl.fragment(on: '__InputValue', doc: doc) do |v|
          v.name
          v.description
          v.type type_ref_fragment
          v.default_value
        end
      end
    end
  end
end
