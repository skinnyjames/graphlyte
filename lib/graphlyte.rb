require 'json'
require_relative "./graphlyte/fieldset"
require_relative "./graphlyte/query"
require_relative "./graphlyte/fragment"
require_relative 'graphlyte/inline_fragment'
require_relative "./graphlyte/schema_query"
require_relative "./graphlyte/types"
require_relative "./graphlyte/schema/parser"

module Graphlyte
  extend SchemaQuery

  TYPES = Types.new

  def self.parse(gql)
    Graphlyte::Schema::Parser.parse(gql)
  end

  def self.query(name = nil, &block)
    Query.new(name, :query, builder: build(&block))
  end

  def self.mutation(name = nil, &block)
    Query.new(name, :mutation, builder: build(&block))
  end

  def self.custom(name, type, &block)
    Query.new(name, type.to_sym, builder: build(&block))
  end

  def self.inline_fragment(model_name, &block)
    InlineFragment.new(model_name, builder: build(&block))
  end

  def self.inline_directive(directive, **hargs, &block)
    InlineFragment.from_directive(directive, **hargs, builder: build(&block) )
  end

  def self.fragment(fragment_name, model_name, &block)
    Fragment.new(fragment_name, model_name, builder: build(&block))
  end

  def self.fieldset(model_name=nil, &block)
    Fieldset.new(model_name, builder: build(&block))
  end

  private

  def self.build(&block)
    builder = Builder.new
    builder.>.instance_eval(&block)
    builder
  end
end
