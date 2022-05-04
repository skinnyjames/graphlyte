# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'
require_relative './collect_variable_references'
require_relative './annotate_types'

module Graphlyte
  module Editors
    # Use variable values to infer missing variables in the query signature
    class WithVariables
      CannotInfer = Class.new(StandardError)
      TypeMismatch = Class.new(StandardError)

      def initialize(schema = nil, operation, variables)
        @schema = schema
        @operation = operation
        @variables = variables
      end

      def edit(doc)
        Editors::SelectOperation.new(@operation).edit(doc) if @operation
        Editors::AnnotateTypes.new(@schema).edit(doc) if @schema

        references = Editors::CollectVariableReferences.new.edit(doc)

        editor = Editor.new.on_operation do |operation, action|
          refs = references[operation.class][operation.name]
          next unless refs

          operation.variables ||= []
          current_vars = operation.variables.to_h { [_1.variable, _1] }

          added = {}
          refs.to_a.reject { current_vars[_1.variable] }.each do |ref|
            infer(operation.variables, added, doc, ref)
          end
        end

        editor.edit(doc)
      end

      def infer(variables, added, doc, ref)
        # Only way this could happen is if `uniq` produces duplicate names
        # And that can only happen if there are two types inferred
        # for the same reference.
        if prev = added[ref.variable]
          raise TypeMismatch, "#{ref.variable}: #{ref.inferred_type} != #{prev.type}"
        end

        var = doc.variables[ref.variable]

        var ||= Syntax::VariableDefinition.new(variable: ref.variable, type: ref.inferred_type)
        var.type ||= ref.inferred_type
        var.type ||= runtime_type_of(@variables[ref.variable])

        raise CannotInfer, ref.variable unless var.type

        variables << var
        added[ref.variable] = var
      end

      def runtime_type_of(value)
        case value
        when Integer
          Syntax::Type.non_null('Int')
        when Float
          Syntax::Type.non_null('Float')
        when String
          Syntax::Type.non_null('String')
        when Date
          Syntax::Type.non_null('Date')
        when TrueClass, FalseClass
          Syntax::Type.non_null('Boolean')
        when Array
          Syntax::Type.list_of(runtime_type_of(value.first)) unless value.empty?
        end
      end
    end
  end
end
