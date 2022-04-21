require 'json'

require_relative "./graphlyte/schema_query"

require_relative "./graphlyte/parser"
require_relative "./graphlyte/lexer"
require_relative "./graphlyte/syntax"
require_relative "./graphlyte/serializer"
require_relative "./graphlyte/selection_builder"

module Graphlyte
  extend SchemaQuery

  def self.parse(gql)
    ts = Graphlyte::Lexer.lex(gql)
    parser = Graphlyte::Parser.new(tokens: ts)

    parser.document
  end

  def self.query(name = nil, doc = Document.new, &block)
    op = Syntax::Operation.new(type: :query)
    doc.define(op)

    op.name = name
    op.selection = SelectionBuilder.build(doc, &block)

    # TODO: infer operation signatures (requires schema!)
    doc
  end

  def self.mutation(name = nil, doc = Document.new, &block)
    op = Syntax::Operation.new(type: :mutation)
    doc.define(op)

    op.name = name
    op.selection = SelectionBuilder.build(doc, &block)

    # TODO: infer operation signatures (requires schema!)
    doc
  end

  def self.fragment(fragment_name = nil, doc = Document.new, on:, &block)
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

    frag
  end
end
