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

    def query(name = nil, doc = Document.new, &block)
      op = Syntax::Operation.new(type: :query)
      doc.define(op)

      op.name = name

      outer = eval('self', block.binding)
      op.selection = SelectionBuilder.build(doc, outer: outer, &block)

      Editors::InferSignature.new(@schema).edit(doc)

      doc
    end

    def mutation(name = nil, doc = Document.new, &block)
      op = Syntax::Operation.new(type: :mutation)
      doc.define(op)

      op.name = name

      outer = eval('self', block.binding)
      op.selection = SelectionBuilder.build(doc, outer: outer, &block)

      # TODO: infer operation signatures (requires schema!)
      doc
    end

    def fragment(fragment_name = nil, doc = Document.new, on:, &block)
      frag = Graphlyte::Syntax::Fragment.new

      frag.type_name = on

      outer = eval('self', block.binding)
      frag.selection = SelectionBuilder.build(doc, outer: outer, &block)

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
