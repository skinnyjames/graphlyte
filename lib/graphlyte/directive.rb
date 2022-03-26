require_relative 'arguments/set'

module Graphlyte
  class Directive
    attr_reader :name, :inputs

    def initialize(name, **hargs)
      @name = name
      @inputs = Arguments::Set.new(hargs)
    end

    def inflate(indent, string, field: nil)
      # add directive after fieldname?
      string += ' ' * indent
      string += "#{field} " if field
      string += "@#{name}"
      string += @inputs.to_s unless @inputs.to_s.empty?
      string
    end
  end
end