# frozen_string_literal: true

require_relative './dsl'

module Graphlyte
  class Interface < DSL
    def initialize(*)
      @builder = nil
      super(nil)
    end

    def register(builder)
      @builder = builder
    end

    def query(&block)
      super(scope: clone, &block)
    end

    def mutation(&block)
      super(scope: clone, &block)
    end

    def fragment(name = nil, on:, &block)
      super(name, on: on, scope: clone, &block)
    end

    private def method_missing(symbol, *args, **kwargs, &block)
      @builder.send(symbol, *args, **kwargs, &block)
    end
  end
end
