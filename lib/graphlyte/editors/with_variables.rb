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

      def initialize(schema, operation, variables)
        @schema = schema
        @operation = operation
        @variables = variables
      end

      def edit(doc)
        select_operation(doc)
        annotate_types(doc)

        references = Editors::CollectVariableReferences.new.edit(doc)
        editor = infer_variable_type(references)

        editor.edit(doc)
      end

      def annotate_types(doc)
        Editors::AnnotateTypes.new(@schema).edit(doc) if @schema
      end

      def select_operation(doc)
        Editors::SelectOperation.new(@operation).edit(doc) if @operation
      end

      def infer_variable_type(references)
        Editor.new.on_operation do |operation, editor|
          refs = references[operation.class][operation.name]
          next unless refs

          infer_operation(operation, refs, editor.document)
        end
      end

      def infer_operation(operation, refs, document)
        current_vars = current_operation_variables(operation)

        added = {}
        refs.to_a.reject { current_vars[_1.variable] }.each do |ref|
          # Only way this could happen is if `uniq` produces duplicate names
          # And that can only happen if there are two types inferred
          # for the same reference.
          if (prev = added[ref.variable])
            raise TypeMismatch, "#{ref.variable}: #{ref.inferred_type} != #{prev.type}"
          end

          infer(operation.variables, added, document, ref)
        end
      end

      def current_operation_variables(operation)
        operation.variables ||= []
        operation.variables.to_h { [_1.variable, _1] }
      end

      def infer(variables, added, doc, ref)
        var = doc.variables.fetch(ref.variable, ref.to_definition)
        type = var.type || ref.inferred_type || runtime_type_of(ref)

        if type
          var.type ||= type
          variables << var
          added[ref.variable] = var
        else
          cannot_infer!(ref)
        end
      end

      def cannot_infer!(ref)
        raise CannotInfer, ref.variable
      end

      def runtime_type_of(ref)
        value = @variables[ref.variable]

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
