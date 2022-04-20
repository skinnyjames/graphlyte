# frozen_string_literal: true

require "forwardable"

require_relative './syntax'

module Graphlyte
  class Document
    extend Forwardable

    attr_reader :definitions, :operations, :fragments

    def_delegators :@definitions, :length, :empty?

    def initialize(definitions = [])
      @definitions = definitions
    end

    def fragments
      @fragments ||= definitions.select { _1.is_a?(Graphlyte::Syntax::Fragment) }.to_h do
        [_1.name, _1]
      end
    end

    def operations
      @operations ||= @definitions.select { _1.is_a?(Graphlyte::Syntax::Operation) }.to_h do
        [_1.name, _1]
      end
    end

    def executable?
      @definitions.all?(&:executable?)
    end
  end
end
