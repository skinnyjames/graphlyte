# frozen_string_literal: true

require_relative './syntax'
require_relative './editor'

module Graphlyte
  # A tool for simple editing of GraphQL queries using a path-based API
  #
  # Usage:
  #
  #   editor = Selector.new
  #   editor.at('project.pipelines.nodes.status', &:remove)
  #   editor.at('project.pipelines.nodes') do |node|
  #     node.append do
  #       downstream do
  #         nodes { active }
  #       end
  #     end
  #
  #   editor.edit(doc)
  #
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

      doc
    end

    def edit_field(field, action)
      key = action.path.map { _1.name if _1.is_a?(Syntax::Field) }.compact.join('.')
      block = @actions[key]

      block&.call(SelectAction.new(field, action))
    end

    # Each block defined with `at` receives as its only argument a
    # `SelectAction`. This object exposes method allowing the caller
    # to modify the query.
    class SelectAction
      def initialize(field, action)
        @field = field
        @action = action
      end

      # Remove the current node.
      def remove
        @action.delete
      end

      # Construct a new selection using the block, and append it to the
      # current field selection.
      def append(&block)
        selection = SelectionBuilder.build(@action.document, &block)

        @field.selection += selection
      end
    end
  end
end
