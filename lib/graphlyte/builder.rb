require_relative "./field"
require_relative "./fieldset"

module Graphlyte
  class Builder
    def initialize(fields = [])
      @fields = fields
    end

    def <<(buildable)
      raise "Must pass a Fieldset or Fragment" unless [Fragment, Fieldset].include?(buildable.class)

      @fields.concat(buildable.fields) if buildable.class.eql? Fieldset

      # todo: handle fragments better, it's not a field
      @fields << buildable if buildable.class.eql? Fragment
    end
    
    def method_missing(method, fieldset_or_hargs=nil, hargs={}, &block)
      # todo: camel case method

      # hack for ruby bug in lower versions
      if [Fieldset, Fragment].include?(fieldset_or_hargs.class)
        field = Field.new(method, fieldset_or_hargs, hargs)
      else
        field = Field.new(method, Fieldset.empty, fieldset_or_hargs)
      end

      field.fieldset.builder.>.instance_eval(&block) if block
      @fields << field
      field
    end

    def respond_to_missing
      true
    end

    # for internal use only
    def >>
      @fields
    end

    def >
      self
    end
  end
end