require_relative "./fieldset"

module Graphlyte
  class Fragment < Fieldset
    attr_reader :fragment

    def initialize(fragment_name, model_name=nil, **hargs)
      @fragment = fragment_name
      super(model_name, **hargs)
    end

    def to_s(indent=0)
      actual_indent = ("\s" * indent) * 2
      "#{actual_indent}...#{fragment}#{actual_indent}"
    end
  end
end