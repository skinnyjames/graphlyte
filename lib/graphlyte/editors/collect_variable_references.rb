# frozen_string_literal: true

require 'set'

require_relative '../editor'
require_relative './inline_fragments'

module Graphlyte
  module Editors
    class CollectVariableReferences
      def edit(doc)
        doc = doc.dup
        references = {}

        collector = Editor.new.on_variable_reference do |ref, action|
          references[action.definition] ||= [].to_set
          references[action.definition] << ref
        end

        InlineFragments.new.edit(doc)
        collector.edit(doc)

        references
      end
    end
  end
end
