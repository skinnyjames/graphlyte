require 'json'
module Graphlyte
  def self.query(name = nil, &block)
    query = Query.new(name)
    block.call(query) if block
    query
  end

  def self.fragment(fragment_name, model_name=nil, &block) 
    fragment = Fragment.new(fragment_name, model_name)
    block.call(fragment) if block
    fragment
  end

  def self.fieldset(model_name=nil, &block)
    fieldset = Fieldset.new(model_name)
    block.call(fieldset) if block
    fieldset
  end
  
  module Buildable
    def <<(buildable)
      raise "Must pass a Fieldset or Fragment" unless [Fragment, Fieldset].include?(buildable.class)
      @fields.concat(buildable._fields) if buildable.class.eql? Fieldset
      @fields << buildable if buildable.class.eql? Fragment
    end
    
    def method_missing(method, optional_fieldset_or_args=nil, hargs={}, &block)
      field = [Fieldset, Fragment].include?(optional_fieldset_or_args.class) ?
        Field.new(method, optional_fieldset_or_args, hargs) :
        Field.new(method, Fieldset.empty, optional_fieldset_or_args)
      block.call(field.value) if block
      @fields << field
      field
    end
  end

  class Fieldset
    include Buildable
    
    def self.empty
      new
    end

    def initialize(model_name = nil)
      @model_name = model_name
      @fields = []
    end

    def _model_name
      @model_name
    end

    def _fields
      @fields
    end

    def empty?
      @fields.empty?
    end

    def can_validate?
      !@model_name.nil?
    end

    def to_s(indent=0)
      @fields.map { |field| field.to_s(indent)}.join("\n")
    end
  end

  class Query < Fieldset

    def initialize(query_name=nil)
      @query_name = query_name
      @fields = []
    end

    def to_json
      { query: to_s }.to_json
    end

    def to_s(indent=0)
      "{\n#{super(indent + 1)}\n}\n#{format_fragments}\n"
    end
    
    def format_fragments
      str = ""
      flatten(@fields).each do |_, fragment|
        str += "\nfragment #{fragment.name}"
        str += " on #{fragment._model_name}" unless fragment._model_name.nil?
        str += " {\n#{fragment._fields.map {|f| f.to_s(1) }.join("\n")}\n}"
      end
      str
    end

    def flatten(fields=@fields, new_fields = {})
      fields.each do |field|
        if field.class.eql?(Fragment)
          new_fields[field.name] = field
          unless field._fields.empty?
            flatten(field._fields, new_fields)
          end
        else
          if field.value.class.eql?(Fragment)
            new_fields[field.value.name] = field.value
            flatten(field.value._fields, new_fields) unless field.value._fields.empty?
          else
            flatten(field.value._fields, new_fields) unless field.value._fields.empty?
          end
        end
      end
      new_fields
    end
  end

  class Fragment < Fieldset
    attr_reader :fragment_name, :name

    def initialize(fragment_name, model_name=nil)
      @fragment_name = fragment_name
      @name = fragment_name
      super(model_name)
    end

    def to_s(indent=0)
      actual_indent = ("\s" * indent) * 2
      "#{actual_indent}...#{@fragment_name}#{actual_indent}"
    end
  end

  class FieldArguments
    def initialize(data)
      @data = data
    end
    
    def to_s
      return @data && !@data.empty? ? "(#{@data.map{|k, v| "#{k}: \"#{v}\""}.join(", ")})" : ""
    end
  end

  class Field
    attr_reader :name, :value, :inputs, :alias

    def initialize(name, value=nil, hargs)
      @name = name
      @value = value
      @inputs = FieldArguments.new(hargs)
      @alias = nil
    end

    def atomic?
      value.empty?
    end

    def alias(name, &block)
      @alias = name
      block.call(value) if block
    end

    def to_s(indent=0)
      str = ""
      actual_indent = ("\s" * indent) * 2
      if @alias
        str += "#{actual_indent}#{@alias}: #{name}"
        str += inputs.to_s.empty? ? "()" : inputs.to_s 
        str += " "
      else
        str += "#{actual_indent}#{name}#{inputs.to_s}"
      end
      str += "{\n#{value.to_s(indent + 1)}#{actual_indent}\n#{actual_indent}}" unless atomic?
      str
    end
  end
end
