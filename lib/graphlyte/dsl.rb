# frozen_string_literal: true

require_relative './syntax'
require_relative './selection_builder'
require_relative './refinements/string_refinement'
require_relative './editors/infer_signature'

module Graphlyte
  # The DSL methods for query construction are defined here.
  #
  # The main methods are:
  #
  # - `var`: creates a fresh unique variable
  # - `enum`: allows referring to enum values
  # - `fragment`: creates a fragment that can be re-used in operations
  # - `query`: creates a `Query` operation
  # - `mutation`: creates a `Mutation` operation
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
      op.selection = SelectionBuilder.build(doc, &block)

      Editors::InferSignature.new(@schema).edit(doc)

      doc
    end

    def mutation(name = nil, doc = Document.new, &block)
      op = Syntax::Operation.new(type: :mutation)
      doc.define(op)

      op.name = name
      op.selection = SelectionBuilder.build(doc, &block)

      # TODO: infer operation signatures (requires schema!)
      doc
    end

    def fragment(fragment_name = nil, on:, doc: Document.new, &block)
      frag = Graphlyte::Syntax::Fragment.new

      frag.type_name = on
      frag.selection = SelectionBuilder.build(doc, &block)

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

      doc.define(frag)

      frag
    end
  end
end
