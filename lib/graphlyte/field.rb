require_relative "./arguments/set"
require_relative 'directive'
require_relative "./refinements/string_refinement"
module Graphlyte
  class Field
    using Refinements::StringRefinement

    attr_reader :name, :fieldset, :inputs, :directive

    def initialize(name, fieldset, hargs, directive: nil, inputs: Arguments::Set.new(hargs))
      @name = name.to_s.to_camel_case
      @fieldset = fieldset
      @inputs = inputs
      @alias = nil
      @directive = directive
    end

    def atomic?
      fieldset.empty?
    end

    def alias(name, &block)
      @alias = name
      if block
        fieldset.builder.>.instance_eval(&block)
      else
        self
      end
    end

    def include(**hargs, &block)
      make_directive('include', **hargs, &block)
    end

    def skip(**hargs, &block)
      make_directive('skip', **hargs, &block)
    end

    def to_s(indent=0)
      str = ""
      actual_indent = ("\s" * indent) * 2
      if @alias
        str += "#{actual_indent}#{@alias}: #{name}"
        str += inputs.to_s.empty? ? "()" : inputs.to_s
      elsif @directive
        str = @directive.inflate(indent * 2, str, field: name)
      else
        str += "#{actual_indent}#{name}#{inputs.to_s}"
      end
      str += " {\n#{fieldset.to_s(indent + 1)}\n#{actual_indent}}" unless atomic?
      str
    end

    private

    def method_missing(symbol, **hargs, &block)
      make_directive(symbol.to_s, **hargs, &block)
    end

    def make_directive(name, **hargs, &block)
      @directive = Directive.new(name, **hargs)
      fieldset.builder.>.instance_eval(&block) if block
    end
  end
end