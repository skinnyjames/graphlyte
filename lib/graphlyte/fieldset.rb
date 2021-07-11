require_relative "./builder"

module Graphlyte
  class Fieldset    
    def self.empty
      new
    end

    attr_reader :model_name, :builder

    def initialize(model_name = nil, builder: Builder.new)
      @model_name = model_name
      @builder = builder
    end

    def fields
      builder.>>
    end

    def empty?
      fields.empty?
    end

    def to_s(indent=0)
      fields.map { |field| field.to_s(indent)}.join("\n")
    end
  end
end