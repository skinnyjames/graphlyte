# frozen_string_literal: true

require_relative "./syntax"
require_relative "./selection_builder"
require_relative './refinements/string_refinement'
require_relative "./editors/infer_signature"

module Graphlyte
  class DSL
    using Graphlyte::Refinements::StringRefinement

    attr_reader :schema

    def initialize(schema = nil)
      @schema = schema
    end

    def var(type = nil, name = nil)
      SelectionBuilder::Variable.new(type: type, name: name&.to_s&.camelize)
    end

    def enum(value)
      Syntax::Value.new(value.to_sym, :ENUM)
    end

    def query(
      name = nil,
      op: Syntax::Operation.new(name: name, type: :query),
      doc: Document.new(definitions: [op]),
      builder: SelectionBuilder,
      scope: nil,
      &block
    )
      op.selection = builder.build(doc, scope: scope, &block)

      Editors::InferSignature.new(@schema).edit(doc)
      doc
    end

    def mutation(
      name = nil,
      op = Syntax::Operation.new(name: name, type: :mutation),
      doc = Document.new(definitions: [op]),
      builder: SelectionBuilder,
      scope: nil,
      &block
    )
      op.selection = builder.build(doc, scope: scope, &block)

      # TODO: infer operation signatures (requires schema!)
      doc
    end

    def fragment(
      fragment_name = nil,
      doc = Document.new,
      on:,
      scope: nil,
      builder: SelectionBuilder,
      frag: Graphlyte::Syntax::Fragment.new(type_name: on),
      &block
    )

      frag.selection = builder.build(doc, scope: scope, &block)

      if fragment_name
        frag.name = fragment_name
      else
        base = "#{on}Fields"
        n = 1
        frag.name = base

        while doc.fragments[frag.name]
          frag.name = "#{base}_#{n}"
          n += 1
        end
      end

      doc.fragments.each_value do |required|
        frag.refers_to required
      end

      frag
    end
  end
end
