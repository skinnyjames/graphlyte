require_relative "./refinements/string_refinement"
require "json"
module Graphlyte
  class Selector
    def initialize(selector)
      @selector_tokens = selector.split('.')
    end

    def modify(fields, selector_tokens = @selector_tokens, &block)
      token = selector_tokens.shift

      if token == '*'
        fields.each do |field|
          next if field.class == Fragment

          modify(field.fieldset.fields, [token], &block)
          field.fieldset.builder.instance_eval(&block) unless field.fieldset.fields.empty?
        end
      else
        needle = fields.find do |field|
          field.name == token
        end

        raise "#{token} not found in query" unless needle

        if selector_tokens.size.zero?
          needle.fieldset.builder.instance_eval(&block)
        else
          modify(needle.fieldset.fields, selector_tokens, &block)
        end
      end
    end
  end

  class Query < Fieldset
    using Refinements::StringRefinement
    attr_reader :name, :type

    def initialize(query_name=nil, type=:query, **hargs)
      @name = query_name || "anonymousQuery"
      @type = type
      super(**hargs)
    end

    def at(selector, &block)
      Selector.new(selector).modify(fields, &block)
    end

    def placeholders
      flatten_variables(builder.>>).map do |value|
        unless value.formal?
          str = ":#{value.value.to_sym.inspect} of unknown"
        else
          str = ":#{value.value.placeholder} of #{value.value.name}"
        end

        if value.value.default
          str += " with default "
          value.value.default.merge!(str)
        end
        str
      end.join("\n")
    end

    def to_json(query_name=name, **hargs)
      variables = flatten_variables(builder.>>).uniq { |v| v.value }
      types = merge_variable_types(variables, hargs)

      str = "#{type} #{query_name}"
      unless types.empty?
        type_new = types.map do |type_arr|
          type_str = "$#{type_arr[0].to_camel_case}: #{type_arr[1]}"
          unless type_arr[2].nil?
            type_str << " = "
            type_arr[2].merge!(type_str)
          end
          type_str
        end
        str += "(#{type_new.join(", ")})"
      end
      { query: "#{str} #{to_s(1)}", variables: Arguments::Set.new(hargs).to_h(true) }.to_json
    end

    def to_s(indent=0)
      "{\n#{super(indent + 1)}\n}#{format_fragments}"
    end
    
    def merge_variable_types(variables=[], hargs)
      variables.inject([]) do |memo, var|
        unless var.formal?
          if hargs[var.value].is_a? String
            memo << [var.value.to_camel_case, "String"]
          elsif [TrueClass, FalseClass].include? hargs[var.value].class
            memo << [var.value ,"Boolean"]
          elsif hargs[var.value].is_a? Float
            memo << [var.value, "Float"]
          elsif hargs[var.value].is_a? Integer
            memo << [var.value, "Int"]
          elsif hargs[var.value].is_a? Array
            memo << "[#{merge_variable_types(var.value, hargs).first}]"
          end
        else
          memo << [var.value.placeholder, var.value.name, var.value.default]
        end
        memo
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
        variables.concat field.inputs.extract_variables unless [InlineFragment, Fragment].include? field.class
        variables.concat field.directive.inputs.extract_variables if field.directive
        if [InlineFragment, Fragment].include? field.class
          flatten_variables(field.fields, variables)
        else
          flatten_variables(field.fieldset.fields, variables)
        end
      end
      variables
    end

    def flatten(fields, new_fields = {})
      fields.each do |field|
        next if field.class == InlineFragment
        if field.class.eql?(Fragment)
          new_fields[field.fragment] = field
          unless field.empty?
            flatten(field.fields, new_fields)
          end
        else
          if field.fieldset.class.eql?(Fragment)
            new_fields[field.fieldset.fragment] = field.fieldset
          end
          flatten(field.fieldset.fields, new_fields) unless field.atomic?
        end
      end
      new_fields
    end
  end
end