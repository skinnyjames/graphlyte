# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'
require_relative './inline_fragments'

module Graphlyte
  module Editors
    class Canonicalize
      def edit(doc)
        doc = doc.dup
        InlineFragments.new.edit(doc)
        doc.definitions = doc.definitions.sort_by(&:name)
        # TODO: we should also perform the selection Merge operation here.
        order_argments.edit(doc)
      end

      def order_argments
        Editor.new
              .on_field { |field| field.arguments = field.arguments&.sort_by(&:name) }
              .on_directive { |dir| dir.arguments = dir.arguments&.sort_by(&:name) }
      end
    end
  end
end
