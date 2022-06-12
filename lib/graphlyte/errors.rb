# frozen_string_literal: true

module Graphlyte
  Invalid = Class.new(StandardError)

  IllegalValue = Class.new(ArgumentError)

  ParseError = Class.new(StandardError)

  TooDeep = Class.new(StandardError) do
    def initialize(location)
      super("Max parse depth exceeded at #{location}")
    end
  end

  Unexpected = Class.new(ParseError) do
    def initialize(token)
      super("Unexpected token at #{token.location}: #{token.lexeme.inspect}")
    end
  end

  Expected = Class.new(ParseError) do
    def initialize(token, expected:)
      super("Unexpected token at #{token.location}: #{token.lexeme.inspect}, expected #{expected}")
    end
  end

  Illegal = Class.new(ParseError) do
    def initialize(token, reason = nil)
      msg = +"Illegal token at #{token.location}: #{token.lexeme}"
      msg << ", #{reason}" if reason
      super(msg)
    end
  end
end
