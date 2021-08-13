require_relative "./refinements/string_refinement"
module Graphlyte
  class Query < Fieldset
    using Refinements::StringRefinement
    attr_reader :name

    def initialize(query_name=nil, **hargs)
      @name = query_name
      super(**hargs)
    end

    def to_json(name="anonymousQuery", **hargs)
      variables = flatten_variables(builder.>>)
      types = merge_variable_types(variables, hargs)
      
      str = "query #{name}"
      unless types.empty?
        type_new = types.map do |type_arr|
          "$#{type_arr[0].to_camel_case}: #{type_arr[1]}"
        end
        str += "(#{type_new.join(", ")})"
      end
      { query: "#{str} #{to_s(1)}", variables: Arguments::Set.new(hargs).to_h }.to_json
    end

    def to_s(indent=0)
      "{\n#{super(indent + 1)}\n}#{format_fragments}"
    end
    
    def merge_variable_types(variables=[], hargs)
      variables.inject([]) do |memo, var|
        if hargs[var.value].is_a? String
          memo << [var.value.to_camel_case, "String"]
        elsif [TrueClass, FalseClass].include? hargs[var.value].class
          memo << [var.value ,"Boolean"]
        elsif hargs[var.value].is_a? Float
          memo << [var.value, "Float"]
        elsif hargs[var.value].is_a? Integer
          memo << [var.value, "Int"]
        elsif hargs[var.value].is_a? Array
          memo <<  "[#{merge_variable_types(var.value, hargs).first}]"
        end
      end
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

    def flatten_variables(fields, variables=[])
      fields.each do |field|
        variables.concat field.inputs.extract_variables
        flatten(field.fieldset.fields, variables)
      end
      variables
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