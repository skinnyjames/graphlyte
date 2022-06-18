# frozen_string_literal: true

require_relative './syntax'

module Graphlyte
  # Walk the document tree and edit or collect data.
  #
  # This is the general purpose recursive transformer for
  # syntax trees, used to write various validators and
  # transformation passes. See `lib/graphlyte/editors`
  #
  # Usage
  #
  # A fragment inliner:
  #
  #   inliner = Editor.new.on_fragment_spread do |spread, action|
  #     action.replace action.document.fragments[spread.name].inline
  #   end
  #
  #   inliner.edit(document)
  #
  # A variable renamer:
  #
  #   renamer = Editor.new.on_variable do |var|
  #     var.variable = 'x' if var.variable == 'y'
  #   end
  #
  #   renamer.edit(document)
  #
  # A string collector:
  #
  #   strings = []
  #   collector = Editor.new.on_value do |value|
  #     strings << value.value if value.type == :STRING
  #   end
  #
  #   collector.edit(document)
  #
  class Editor
    Deleted = Class.new(StandardError)

    attr_accessor :direction

    def initialize
      @hooks = {}
      @direction = :bottom_up
    end

    # The value passed to the handler blocks, in addition to the syntax node.
    # Users can call methods on this object to edit the document in-place, as
    # well as read information about the context of this node.
    class Action
      attr_accessor :new_nodes
      attr_reader :path, :definition, :parent, :document

      def initialize(old_node, path, parent, document)
        @new_nodes = [old_node]
        @definition = path.first
        @path = path.dup.freeze
        @parent = parent
        @document = document
      end

      def replace(replacement)
        @new_nodes = [replacement]
      end

      def insert_before(node)
        @new_nodes = [node] + @new_nodes
      end

      def insert_after(node)
        @new_nodes.push(node)
      end

      def delete
        @new_nodes = []
      end

      def expand(new_nodes)
        @new_nodes = new_nodes
      end

      def closest(node_type)
        @path.reverse.find { _1.is_a?(node_type) }
      end
    end

    # The class responsible for orchestration of the hooks. This class
    # defines the recursion through the document.
    Context = Struct.new(:document, :direction, :hooks, :path) do
      def edit(object, &block)
        parent = path.last
        path.push(object)

        processor = hooks[object.class]
        action = Action.new(object, path, parent, document)

        case direction
        when :bottom_up
          edit_bottom_up(object, processor, action, &block)
        when :top_down
          edit_top_down(object, processor, action, &block)
        else
          raise ArgumentError, "Unknown direction: #{direction}"
        end

        action.new_nodes
      ensure
        path.pop
      end

      def edit_top_down(object, processor, action)
        processor&.call(object, action)
        action.new_nodes = action.new_nodes.filter_map do |node|
          yield node if block_given?
          node
        rescue Deleted
          nil
        end
      end

      def edit_bottom_up(object, processor, action)
        yield object if block_given?
        processor&.call(object, action)
      rescue Deleted
        action.new_nodes = []
      end

      def edit_variables(object)
        return unless object.respond_to?(:variables)

        object.variables = object.variables&.flat_map do |var|
          edit(var) do |v|
            edit_directives(v)
            v.default_value = edit_value(v.default_value).first
          end
        end
      end

      def edit_directives(object)
        return unless object.respond_to?(:directives)

        object.directives = object.directives&.flat_map do |dir|
          edit(dir) { |d| edit_arguments(d) }
        end
      end

      def edit_arguments(object)
        return unless object.respond_to?(:arguments)

        object.arguments = object.arguments&.flat_map do |arg|
          edit(arg) do |_a|
            arg.value = if arg.value.instance_of?(Syntax::InputObject)
                          edit_input_object(arg.value)
                        else
                          edit_value(arg.value).first
                        end

            raise Deleted if arg.value.nil?
          end
        end
      end

      def edit_input_object(object)
        return unless object.respond_to?(:values)

        edit(object) do
          object.values = object.values&.flat_map do |obj|
            edit(obj) do |_i|
              obj.value = if obj.value.is_a?(Syntax::InputObject)
                            edit_input_object(obj.value)
                          else
                            edit_value(obj.value).first
                          end
            end
          end
        end

        object
      end

      def edit_value(object)
        case object
        when Array
          [object.flat_map { edit_value(_1) }]
        # TODO: should be unused
        when Hash
          [
            object.values.flat_map do |(k, old_value)|
              edit_value(old_value).take(1).map do |new_value|
                [k, new_value]
              end
            end.to_h
          ]
        else
          edit(object)
        end
      end

      def edit_selection(object)
        return unless object.respond_to?(:selection)

        object.selection = object.selection&.flat_map do |selected|
          edit(selected) do |s|
            edit_arguments(s)
            edit_directives(s)
            edit_selection(s)
          end
        end
      end

      def edit_definition(object)
        edit(object) do |o|
          edit_variables(o)
          edit_directives(o)
          edit_selection(o)
        end
      end
    end

    def self.top_down
      e = new
      e.direction = :top_down

      e
    end

    def self.bottom_up
      new
    end

    def on_value(&block)
      @hooks[Syntax::Value] = block
      self
    end

    def on_input_object(&block)
      @hooks[Syntax::InputObject] = block
      self
    end

    def on_input_object_arg(&block)
      @hooks[Syntax::InputObjectArgument] = block
    end

    def on_argument(&block)
      @hooks[Syntax::Argument] = block
      self
    end

    def on_directive(&block)
      @hooks[Syntax::Directive] = block
      self
    end

    def on_operation(&block)
      @hooks[Syntax::Operation] = block
      self
    end

    def on_variable(&block)
      on_variable_definition(&block)
      on_variable_reference(&block)
      self
    end

    def on_variable_definition(&block)
      @hooks[Syntax::VariableDefinition] = block
      self
    end

    def on_variable_reference(&block)
      @hooks[Syntax::VariableReference] = block
      self
    end

    # Selected nodes:

    def on_field(&block)
      @hooks[Syntax::Field] = block
      self
    end

    def on_fragment(&block)
      on_inline_fragment(&block)
      on_fragment_definition(&block)
      self
    end

    def on_fragment_spread(&block)
      @hooks[Syntax::FragmentSpread] = block
      self
    end

    def on_inline_fragment(&block)
      @hooks[Syntax::InlineFragment] = block
      self
    end

    def on_fragment_definition(&block)
      @hooks[Syntax::Fragment] = block
      self
    end

    # To edit specific nodes in a document (or isolated from a document)
    # you will need a Context.
    def context(document = nil)
      Context.new(document, direction, @hooks.dup.freeze, [])
    end

    def edit(document)
      c = context(document)

      document.definitions = document.definitions.flat_map do |object|
        c.edit_definition(object)
      end

      document
    end
  end
end
