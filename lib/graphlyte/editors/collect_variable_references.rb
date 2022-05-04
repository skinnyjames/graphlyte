# frozen_string_literal: true

require 'set'

require_relative '../editor'
require_relative './inline_fragments'

module Graphlyte
  module Editors
    class CollectVariableReferences
      def edit(doc)
        doc = doc.dup
        references = { Syntax::Operation => {}, Syntax::Fragment => {} }

        collector = Editor.new.on_variable_reference do |ref, action|
          d = action.definition
          references[d.class][d.name] ||= [].to_set
          references[d.class][d.name] << ref
        end

        InlineFragments.new.edit(doc)
        collector.edit(doc)

        references
      end
    end
  end
end
