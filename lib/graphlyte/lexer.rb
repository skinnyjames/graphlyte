# frozen_string_literal: true

require "forwardable"

# See: https://github.com/graphql/graphql-spec/blob/main/spec/Appendix%20B%20--%20Grammar%20Summary.md
module Graphlyte
  LexError = Class.new(StandardError)

  class Lexer
    LINEFEED = "\u000a"
    CARRIAGE_RETURN = "\u000d"
    NEW_LINE = [LINEFEED, CARRIAGE_RETURN].freeze
    HORIZONTAL_TAB = "\u0009"
    SPACE = "\u0020"
    WHITESPACE = [HORIZONTAL_TAB, SPACE].freeze
    COMMENT_CHAR = '#'
    COMMA = ','
    UNICODE_BOM = "\ufeff"
    IGNORED = [UNICODE_BOM, COMMA, *WHITESPACE].freeze
    PUNCTATOR = ['!', '$', '&', '(', ')', '...', ':', '=', '@', '[', ']', '{', '|', '}'].freeze
    LETTERS = %w[
      A B C D E F G H I J K L M
      N O P Q R S T U V W X Y Z
      a b c d e f g h i j k l m
      n o p q r s t u v w x y z
    ]

    DIGITS = %w[0 1 2 3 4 5 6 7 8 9]

    Position = Struct.new(:line, :col) do
      def to_s
        "#{line}:#{col}"
      end
    end

    class Location
      attr_reader :start_pos, :end_pos

      def initialize(start_pos, end_pos)
        @start_pos = start_pos
        @end_pos = end_pos
      end

      def self.eof
        new(nil, nil)
      end

      def eof?
        start_pos.nil?
      end

      def ==(other)
        other.is_a?(self.class) && to_s == other.to_s
      end

      def to_s
        return 'EOF' if eof?

        "#{start_pos}-#{end_pos}"
      end
    end

    class Token
      extend Forwardable

      attr_reader :type, :lexeme, :literal, :location
      def_delegators :@location, :line, :col, :length

      def initialize(type, lexeme, location, literal: nil)
        @type = type
        @lexeme = lexeme
        @literal = literal
        @location = location
      end
    end

    attr_reader :source, :tokens
    attr_accessor :line, :column, :index, :lexeme_start_p

    def initialize(source)
      @source = source
      @tokens = []
      @line = 0
      @column = 0
      @index = 0
      @lexeme_start_p = Position.new(0, 0)
    end

    def start_tokenization
      while source_uncompleted?
        tokenize
      end

      tokens << Token.new(:eof, nil, after_source_end_location)
    end

    def after_source_end_location
      Location.eof
    end

    def source_uncompleted?
      index < source.length
    end

    def self.lex(source)
      lexer = new(source)
      lexer.start_tokenization

      lexer.tokens
    end

    def lookahead(offset = 1)
      lookahead_p = (index - 1) + offset
      return "\0" if lookahead_p >= source.length

      source[lookahead_p]
    end

    def match(string)
      string.chars.each_with_index.all? do |char, offset|
        lookahead(offset) == char
      end
    end
    
    def take_while(&block)
      chars = []
      while yield(lookahead)
        chars << consume
      end

      chars
    end

    def seek(n)
      self.index += n
    end

    def consume
      c = lookahead
      self.index += 1
      self.column += 1
      c
    end

    def current_location
      Location.new(lexeme_start_p, current_position)
    end

    def current_position
      Position.new(line, column)
    end

    def tokenize
      self.lexeme_start_p = current_position
      token = nil

      c = consume

      return if IGNORED.include?(c)
      return ignore_comment_line if c == COMMENT_CHAR

      if NEW_LINE.include?(c)
        self.line += 1
        self.column = 0
        ignore_newlines

        return
      end

      token =
        if punctator = PUNCTATOR.find { match(_1) }
          seek(punctator.length)
          Token.new(:PUNCTATOR, punctator, current_location)
        elsif name_start?(c)
          name(c)
        elsif string_start?(c)
          string
        elsif numeric_start?(c)
          number
        end

      if token
        tokens << token
      else
        raise LexError, "Unknown character: #{c.inspect} at #{current_location}"
      end
    end

    def string_start?(c)
      false
    end

    def numeric_start?(c)
      false
    end

    def name(c)
      value = [c] + take_while { name_continue?(_1) }

      Token.new(:NAME, value.join(''), current_location)
    end

    def name_start?(c)
      letter?(c) || underscore?(c)
    end

    def name_continue?(c)
      letter?(c) || digit?(c) || underscore?(c)
    end

    def letter?(c)
      LETTERS.include?(c)
    end

    def underscore?(c)
      c == '_'
    end

    def digit?(c)
      DIGITS.include?(c)
    end

    def ignore_comment_line
      consume while !NEW_LINE.include?(lookahead)

      nil
    end

    def ignore_newlines
      while lookahead == LINEFEED
        consume
        self.line += 1
        self.column = 0
      end
    end
  end
end
