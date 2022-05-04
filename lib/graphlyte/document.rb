# frozen_string_literal: true

require "forwardable"

require_relative './syntax'
require_relative './data'
require_relative './serializer'

module Graphlyte
  class Document < Graphlyte::Data
    extend Forwardable

    attr_accessor :definitions, :variables, :schema

    def_delegators :@definitions, :length, :empty?

    def initialize(**kwargs)
      super
      @definitions ||= []
      @variables ||= {}
      @var_name_counter = @variables.size + 1
    end

    def eql?(other)
      other.is_a?(self.class) && other.fragments == fragments && other.operations == operations
    end

    alias_method :==, :eql?

    def define(dfn)
      @definitions << dfn
    end

    def declare(var)
      if var.name.nil?
        var.name = "var#{@var_name_counter}"
        @var_name_counter += 1
      end

      parser = Graphlyte::Parser.new(tokens: Graphlyte::Lexer.lex(var.type))
      parsed_type = parser.type_name! if var.type
      current_def = @variables[var.name]

      if current_def && current_def.type != parsed_type
        msg = "Cannot re-declare #{var.name} at different types. #{current_def.type} != #{var.type}"
        raise ArgumentError, msg
      end

      @variables[var.name] ||= Graphlyte::Syntax::VariableDefinition.new(
        variable: var.name,
        type: parsed_type
      )
    end

    def fragments
      definitions.select { _1.is_a?(Graphlyte::Syntax::Fragment) }.to_h do
        [_1.name, _1]
      end
    end

    def operations
      @definitions.select { _1.is_a?(Graphlyte::Syntax::Operation) }.to_h do
        [_1.name, _1]
      end
    end

    def executable?
      @definitions.all?(&:executable?)
    end

    def to_s
      buff = []
      write(buff)

      buff.join('')
    end

    # More efficient for writing to files or streams - avoids building up the full string.
    def write(io)
      Graphlyte::Serializer.new(io).dump_definitions(definitions)
    end

    # Return this document as a JSON request body, suitable for posting to a server.
    def request_body(operation = nil, **variables)
      if operation.nil? && operations.size != 1
        raise ArgumentError, 'Operation name is required when the document contains multiple operations'
      end

      variables.transform_keys!(&:to_s)

      doc = Editors::WithVariables.new(schema, operation, variables).edit(dup)

      {
        query: doc.to_s,
        variables: variables,
        operation: operation
      }.compact.to_json
    end
  end
end
