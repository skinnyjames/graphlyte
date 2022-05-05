# frozen_string_literal: true

require_relative './syntax'
require_relative './editor'

module Graphlyte
  class Selector
    def initialize
      @actions = {}
    end

    def at(path, &block)
      raise ArgumentError 'block not given' unless block_given?

      @actions[path] = block

      self
    end

    def edit(doc)
      editor = Editor.new.on_field do |field, action|
        edit_field(field, action)
      end

      editor.edit(doc)
    end

    def edit_field(field, action)
      key = action.path.map { _1.name if _1.is_a?(Syntax::Field) }.compact.join('.')
      block = @actions[key]

      block.call(SelectAction.new(field, action)) if block
    end

    class SelectAction
      def initialize(field, action)
        @field = field
        @action = action
      end

      def remove
        @action.delete
      end

      def append(&block)
        selection = SelectionBuilder.build(@action.document, &block)

        @field.selection += selection
      end
    end
  end
end
