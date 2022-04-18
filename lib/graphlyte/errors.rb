# frozen_string_literal: true

module Graphlyte
  IllegalValue = Class.new(StandardError)

  ParseError = Class.new(StandardError)
  Unexpected = Class.new(ParseError) do
    def initialize(token)
      super("Unexpected token at #{token.location}: #{token.lexeme.inspect}")
    end
  end

  Illegal = Class.new(ParseError) do
    def initialize(token, reason = nil)
      msg = "Illegal token at #{token.location}: #{token.lexeme}"
      msg << ", #{reason}" if reason
      super(msg)
    end
  end
end
