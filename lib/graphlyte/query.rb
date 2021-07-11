module Graphlyte
  class Query < Fieldset

    attr_reader :name

    def initialize(query_name=nil, **hargs)
      @name = query_name
      super(**hargs)
    end

    def to_json
      { query: to_s }.to_json
    end

    def to_s(indent=0)
      "{\n#{super(indent + 1)}\n}#{format_fragments}"
    end
    
    def format_fragments
      str = "\n"
      flatten(builder.>>).each do |_, fragment|
        str += "\nfragment #{fragment.fragment}"
        str += " on #{fragment.model_name}" unless fragment.model_name.nil?
        str += " {\n#{fragment.fields.map {|f| f.to_s(1) }.join("\n")}\n}"
      end
      str
    end

    def flatten(fields, new_fields = {})
      fields.each do |field|
        if field.class.eql?(Fragment)
          new_fields[field.fragment] = field
          unless field.empty?
            flatten(field.fields, new_fields)
          end
        else
          if field.fieldset.class.eql?(Fragment)
            new_fields[field.fieldset.fragment] = field.fieldset
            flatten(field.fieldset.fields, new_fields) unless field.atomic?
          else
            flatten(field.fieldset.fields, new_fields) unless field.atomic?
          end
        end
      end
      new_fields
    end
  end
end