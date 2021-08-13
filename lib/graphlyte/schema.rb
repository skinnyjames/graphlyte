require_relative "parsing/parser"
require_relative "schema/types/base"
require_relative "schema/types/enum"
require_relative "schema/types/input_object"
require_relative "schema/types/interface"
require_relative "schema/types/list"
require_relative "schema/types/non_null"
require_relative "schema/types/object"
require_relative "schema/types/scalar"
require_relative "schema/types/union"

module Graphlyte 
  module Schema

    class Definition
      def initialize(schema_payload)
        @schema = JSON.parse(schema_payload.to_json, symbolize_names: true)[:__schema]
      end

      def query_type
        @schema[:queryType][:name]
      end

      def mutation_type 
        @schema[:mutationType][:name]
      end

      def validate(tokens)

      end

      def types
        @schema[:types].map do |type|
        end
      end
    end

    class Loader
      attr_reader :definition

      def initialize(schema_payload)
        @definition = Definition.new schema_payload
      end



      def parse(gql)
        Parsing::Parser.parse(gql, @definition)
      end
    end
  end
end