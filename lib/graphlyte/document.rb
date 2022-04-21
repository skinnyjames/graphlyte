# frozen_string_literal: true

require "forwardable"

require_relative './syntax'
require_relative './serializer'

module Graphlyte
  class Document
    extend Forwardable

    attr_reader :definitions, :operations, :fragments

    def_delegators :@definitions, :length, :empty?

    def initialize(definitions = [])
      @definitions = definitions
    end

    def define(dfn)
      @definitions << dfn
    end

    def fragments
      definitions.select { _1.is_a?(Graphlyte::Syntax::Fragment) }.to_h do
        [_1.name, _1]
      end
    end

    def operations
      @definitions.select { _1.is_a?(Graphlyte::Syntax::Operation) }.to_h do
        [_1.name, _1]
      end
    end

    def executable?
      @definitions.all?(&:executable?)
    end

    def to_s
      buff = []
      write(buff)

      buff.join('')
    end

    # More efficient for writing to files or streams - avoids building up the full string.
    def write(io)
      Graphlyte::Serializer.new(io).dump_definitions(definitions)
    end
  end
end
