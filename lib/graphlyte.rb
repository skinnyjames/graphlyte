# frozen_string_literal: true

require 'forwardable'
require 'json'

require_relative './graphlyte/syntax'
require_relative './graphlyte/schema'
require_relative './graphlyte/lexer'
require_relative './graphlyte/parser'
require_relative './graphlyte/editor'
require_relative './graphlyte/serializer'
require_relative './graphlyte/selector'
require_relative './graphlyte/selection_builder'
require_relative './graphlyte/dsl'
require_relative './graphlyte/schema_query'

# A GraphQL parsing, introspection, construction and manipulation library
module Graphlyte
  extend SchemaQuery
  extend SingleForwardable

  NO_SCHEMA_DSL = Graphlyte::DSL.new

  def_delegators 'Graphlyte::NO_SCHEMA_DSL', :query, :mutation, :var, :fragment

  def self.parse(gql)
    ts = Graphlyte::Lexer.lex(gql)
    parser = Graphlyte::Parser.new(tokens: ts)

    parser.query
  end

  def self.dsl(schema)
    DSL.new(schema)
  end

  def self.load_schema(file = nil)
    schema = file ? File.read(file) : yield(schema_query)
    Schema.from_schema_response(schema)
  end
end
