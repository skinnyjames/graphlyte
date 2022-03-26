require_relative "./fieldset"

module Graphlyte
  class InlineFragment < Fieldset
    attr_reader :directive

    def self.from_directive(directive, **hargs)
      new(nil, directive: directive, **hargs)
    end

    def initialize(model = nil, directive: nil, **hargs)
      @directive = directive
      super(model, **hargs)
    end

    def to_s(indent=0)
      actual_indent = ("\s" * indent) * 2
      string = '... '
      string += "on #{model_name}" if model_name
      inflate_indent = model_name ? 1 : 0
      string = directive.inflate(inflate_indent, string) if directive
      string += " {\n"
      string += super(indent + 1)
      string += "\n#{actual_indent}}"

      "#{actual_indent}#{string}"
    end
  end
end