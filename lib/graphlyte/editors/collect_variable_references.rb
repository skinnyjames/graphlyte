# frozen_string_literal: true

require 'set'

require_relative '../editor'
require_relative './inline_fragments'

module Graphlyte
  module Editors
    # Find all variable references in a document
    class CollectVariableReferences
      attr_reader :references

      def initialize
        @references = { Syntax::Operation => {}, Syntax::Fragment => {} }
      end

      def edit(doc)
        doc = doc.dup

        InlineFragments.new.edit(doc)
        collector.edit(doc)

        references
      end

      def collector
        Editor.new.on_variable_reference do |ref, action|
          d = action.definition
          references[d.class][d.name] ||= [].to_set
          references[d.class][d.name] << ref
        end
      end
    end
  end
end
