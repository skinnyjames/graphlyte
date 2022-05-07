# frozen_string_literal: true

require_relative './dsl'

module Graphlyte
  class Interface < DSL
    def initialize(*args)
      @builder = nil
      super(nil)
    end

    def register(builder)
      @builder = builder
    end

    def query(&block)
      super(scope: self.clone, &block)
    end

    def mutation(&block)
      super(scope: self.clone, &block)
    end

    def fragment(name = nil, on:, &block)
      super(name, on: on, scope: self.clone, &block)
    end

    private def method_missing(symbol, *args, &block)
      @builder.send(symbol, *args, &block)
    end
  end
end