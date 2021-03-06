# frozen_string_literal: true

require_relative './syntax'
require_relative './refinements/string_refinement'

module Graphlyte
  # Helper to build arguments for a field selection.
  class ArgumentBuilder
    using Graphlyte::Refinements::StringRefinement

    def initialize(document)
      @document = document
    end

    def build(arguments)
      return [] unless arguments.any?

      arguments.to_a.map do |(k, v)|
        value = case v
                when Syntax::Value
                  v # built via Graphlyte.enum for example
                when SelectionBuilder::Variable
                  @document.declare(v)
                when Symbol
                  Syntax::VariableReference.new(v.name.camelize)
                else
                  Syntax::Value.from_ruby(v)
                end

        Syntax::Argument.new(k.to_s.camelize, value)
      end
    end
  end

  # The return value from `select!`. Allows further modifications (aliasing,
  # directives) to the field.
  class WithField
    def initialize(field, builder)
      @field = field
      @builder = builder
    end

    def alias(name, &block)
      @field.as = name

      @field.selection += @builder.build!(&block) if block_given?

      self
    end

    def method_missing(name, *_args, **kwargs, &block)
      directive = Syntax::Directive.new(name.to_s)

      directive.arguments = @builder.argument_builder!.build(kwargs) if kwargs.any?

      @field.selection += @builder.build!(&block) if block_given?

      @field.directives << directive

      self
    end

    def respond_to_missing?(*)
      true
    end
  end

  # Main construct used to build selection sets, uses `method_missing` to
  # select fields.
  #
  # Note: instance methods are either symbolic or end in bangs to avoid
  # shadowing legal field names.
  #
  # Usage:
  #
  #   some_fields = %w[all these fields]
  #   selection = SelectionBuilder.build(document) do
  #     foo                             # basic field
  #     bar(baz: 1) { x; y; z}          # field with sub-selection
  #     some_fields.each { self << _1 } # Adding fields dynamically
  #   end
  #
  # You should probably never need to call this directly - it is used to
  # implement the DSL class.
  class SelectionBuilder
    using Graphlyte::Refinements::StringRefinement

    # Variables should not be re-used between queries
    Variable = Struct.new(:type, :name, keyword_init: true)

    def self.build(document, &block)
      return [] unless block_given?

      new(document).build!(&block)
    end

    def initialize(document)
      @document = document
    end

    def build!
      old = @selection
      curr = []
      return curr unless block_given?

      @selection = curr

      yield self

      curr
    ensure
      @selection = old
    end

    def on!(type_name, &block)
      frag = Graphlyte::Syntax::InlineFragment.new
      frag.type_name = type_name
      frag.selection = build!(&block)

      select! frag
    end

    # Selected can be:
    #
    # - a string or symbol (field name)
    # - a Graphlyte::Syntax::{Fragment,Field,InlineFragment}
    # - a SelectionBuilder::Variable (constructed with `DSL#var`).
    #
    # Use of this method (or `select!`) is necessary to add fields
    # that shadow core method or construct names (e.g. `if`, `open`, `else`,
    # `class` and so on).
    def <<(selected)
      select!(selected)
    end

    def select!(selected, *args, **kwargs, &block)
      case selected
      when Graphlyte::Syntax::Fragment
        @document.add_fragments(selected.required_fragments)
        @selection << Graphlyte::Syntax::FragmentSpread.new(name: selected.name)
      when Graphlyte::Syntax::InlineFragment, Graphlyte::Syntax::Field
        @selection << selected
      else
        field = new_field!(selected.to_s, args)
        field.arguments = argument_builder!.build(kwargs)
        field.selection += self.class.build(@document, &block)

        WithField.new(field, self)
      end
    end

    def argument_builder!
      @argument_builder ||= ArgumentBuilder.new(@document)
    end

    private

    def new_field!(name, args)
      field = Syntax::Field.new(name: name)
      @selection << field

      args.each do |arg|
        case arg
        when Symbol
          field.directives << Syntax::Directive.new(arg.to_s)
        when WithField
          raise ArgumentError, 'Reference error' # caused by typos usually.
        else
          field.selection += self.class.build(@document) { _1.select! arg }
        end
      end

      field
    end

    def method_missing(name, *args, **kwargs, &block)
      if name.to_s.end_with?('=') && args.length == 1 && args[0].is_a?(WithField)
        aka = name.to_s.chomp('=')
        args[0].alias(aka)
      else
        select!(name.to_s.camelize, *args, **kwargs.transform_keys(&:camelize), &block)
      end
    end

    def respond_to_missing?(*)
      true
    end
  end
end
