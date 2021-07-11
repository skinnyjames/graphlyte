require_relative "./arguments/set"

module Graphlyte
  class Field
    attr_reader :name, :fieldset, :inputs, :alias

    def initialize(name, fieldset, hargs, inputs: Arguments::Set.new(hargs))
      @name = name
      @fieldset = fieldset
      @inputs = inputs
      @alias = nil
    end

    def atomic?
      fieldset.empty?
    end

    def alias(name, &block)
      @alias = name
      block.call(fieldset.builder) if block
    end

    def to_s(indent=0)
      str = ""
      actual_indent = ("\s" * indent) * 2
      if @alias
        str += "#{actual_indent}#{@alias}: #{name}"
        str += inputs.to_s.empty? ? "()" : inputs.to_s 
      else
        str += "#{actual_indent}#{name}#{inputs.to_s}"
      end
      str += " {\n#{fieldset.to_s(indent + 1)}\n#{actual_indent}}" unless atomic?
      str
    end
  end
end