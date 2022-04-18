# frozen_string_literal: true

require "forwardable"

module Graphlyte
  class Document
    extend Forwardable

    def_delegators :@definitions, :length, :<<, :empty?

    def initialize
      @definitions = []
    end

    def executable?
      @definitions.all?(&:executable?)
    end
  end
end
