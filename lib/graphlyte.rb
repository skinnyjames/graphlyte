# frozen_string_literal: true

require 'forwardable'
require 'json'
require 'rest-client'

require_relative "./graphlyte/syntax"
require_relative "./graphlyte/schema"
require_relative "./graphlyte/lexer"
require_relative "./graphlyte/parser"
require_relative "./graphlyte/editor"
require_relative "./graphlyte/serializer"
require_relative "./graphlyte/selection_builder"
require_relative "./graphlyte/dsl"
require_relative "./graphlyte/schema_query"

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

  def self.dsl(uri, headers = {})
    DSL.new(request_schema(uri, headers))
  end

  def self.request_schema(uri, headers = {})
    body = { query: schema_query.to_s }.to_json
    headers = { content_type: :json, accept: :json }.merge(headers)

    resp = RestClient.post(uri, body, headers)

    Schema.from_schema_response(JSON.parse(resp.body))
  end
end
