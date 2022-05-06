# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'
require_relative './collect_variable_references'
require_relative './annotate_types'

module Graphlyte
  module Editors
    class InferSignature
      CannotInfer = Class.new(StandardError)
      TypeMismatch = Class.new(StandardError)

      def initialize(schema = nil)
        @schema = schema
      end

      def edit(doc)
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

        # We should *always* be able to infer if there is a schema
        # But if we are in dynamic mode, defer inferrence errors until
        # we have runtime values (see `WithVariables`)
        # TODO: combine this class with `WithVariables` - they share a lot of code!
        raise CannotInfer, ref.variable if @schema && !var.type
        return unless var.type

        variables << var
        added[ref.variable] = var
      end
    end
  end
end
