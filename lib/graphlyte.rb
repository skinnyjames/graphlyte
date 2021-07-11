require 'json'
require_relative "./graphlyte/fieldset"
require_relative "./graphlyte/query"
require_relative "./graphlyte/fragment"

module Graphlyte
  def self.query(name = nil, &block)
    Query.new(name, builder: build(&block))
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
    block.call(builder) if block
    builder
  end
end
