require 'json'
require_relative "./graphlyte/fieldset"
require_relative "./graphlyte/query"
require_relative "./graphlyte/fragment"
require_relative "./graphlyte/schema"

module Graphlyte
  extend Schema

  def self.query(name = nil, &block)
    Query.new(name, builder: build(&block))
  end

  def self.fragment(fragment_name, model_name, &block)
    Fragment.new(fragment_name, model_name, builder: build(&block))
  end

  def self.fieldset(model_name=nil, &block)
    Fieldset.new(model_name, builder: build(&block))
  end

  def self.parse(input)
    NewParser.parse(input)
  end

  private

  def self.build(&block)
    builder = Builder.new
    builder.>.instance_eval(&block)
    builder
  end
end
