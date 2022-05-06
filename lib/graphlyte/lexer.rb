# frozen_string_literal: true

require 'forwardable'

# See: https://github.com/graphql/graphql-spec/blob/main/spec/Appendix%20B%20--%20Grammar%20Summary.md
#
# This module implements tokenization of
# [Lexical Tokens](https://github.com/graphql/graphql-spec/blob/main/spec/Appendix%20B%20--%20Grammar%20Summary.md#lexical-tokens)
# as per the GraphQL spec.
#
# Usage:
#
#   > Graphlyte::Lexer.lex(source)
#
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
    DOUBLE_QUOTE = '"'
    BLOCK_QUOTE = '"""'
    BACK_QUOTE = '\\'
    COMMA = ','
    UNICODE_BOM = "\ufeff"
    IGNORED = [UNICODE_BOM, COMMA, *WHITESPACE].freeze
    PUNCTATOR = ['!', '$', '&', '(', ')', '...', ':', '=', '@', '[', ']', '{', '|', '}'].freeze
    LETTERS = %w[
      A B C D E F G H I J K L M
      N O P Q R S T U V W X Y Z
      a b c d e f g h i j k l m
      n o p q r s t u v w x y z
    ].freeze

    DIGITS = %w[0 1 2 3 4 5 6 7 8 9].freeze

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

      def to(location)
        self.class.new(start_pos, location.end_pos)
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

      attr_reader :type, :lexeme, :location

      def_delegators :@location, :line, :col, :length

      def initialize(type, lexeme, location, value: nil)
        @type = type
        @lexeme = lexeme
        @value = value
        @location = location
      end

      def value
        @value || @lexeme
      end

      def punctator?(value)
        @type == :PUNCTATOR && @lexeme == value
      end
    end

    attr_reader :source, :tokens
    attr_accessor :line, :column, :index, :lexeme_start_p

    def initialize(source)
      @source = source
      @tokens = []
      @line = 1
      @column = 1
      @index = 0
      @lexeme_start_p = Position.new(0, 0)
    end

    def self.lex(source)
      lexer = new(source)
      lexer.tokenize!

      lexer.tokens
    end

    def tokenize!
      while source_uncompleted?
        self.lexeme_start_p = current_position

        token = next_token

        tokens << token if token
      end

      tokens << Token.new(:EOF, nil, after_source_end_location)
    end

    private

    def after_source_end_location
      Location.eof
    end

    def source_uncompleted?
      index < source.length
    end

    def eof?
      !source_uncompleted?
    end

    def lookahead(offset = 1)
      lookahead_p = (index - 1) + offset
      return "\0" if lookahead_p >= source.length

      source[lookahead_p]
    end

    def match(str)
      str.chars.each_with_index.all? do |char, offset|
        lookahead(offset + 1) == char
      end
    end

    def lex_error(msg)
      raise LexError, "#{msg} at #{line}:#{column}"
    end

    def one_of(strings)
      strings.each do |s|
        return s if consume(s)
      end

      nil
    end

    def string(_c)
      if lookahead == DOUBLE_QUOTE && lookahead(2) != DOUBLE_QUOTE
        consume
        '' # The empty string
      elsif consume('""') # Block string
        block_string_content
      else
        string_content
      end
    end

    def string_content
      chars = []
      while char = string_character
        chars << char
      end

      lex_error('Unterminated string') unless consume(DOUBLE_QUOTE)

      chars.join
    end

    def string_character(block_string: false)
      return if eof?
      return if lookahead == DOUBLE_QUOTE

      c = consume

      lex_error("Illegal character #{c.inspect}") if !block_string && NEW_LINE.include?(c)

      if c == BACK_QUOTE
        escaped_character
      else
        c
      end
    end

    def escaped_character
      c = consume

      case c
      when DOUBLE_QUOTE then DOUBLE_QUOTE
      when BACK_QUOTE then BACK_QUOTE
      when '/' then '/'
      when 'b' then "\b"
      when 'f' then "\f"
      when 'n' then LINEFEED
      when 'r' then "\r"
      when 't' then "\t"
      when 'u'
        char_code = [1, 2, 3, 4].map do
          d = consume
          hex_digit = (digit?(d) || ('a'...'f').cover?(d.downcase))
          lex_error("Expected a hex digit in unicode escape sequence. Got #{d.inspect}") unless hex_digit

          d
        end

        char_code.join.hex.chr
      else
        lex_error("Unexpected escaped character in string: #{c}")
      end
    end

    def block_string_content
      chars = []
      terminated = false

      until eof? || terminated = consume(BLOCK_QUOTE)
        chars << BLOCK_QUOTE if consume("\\#{BLOCK_QUOTE}")
        chars << '"' while consume(DOUBLE_QUOTE)
        while char = string_character(block_string: true)
          chars << char
        end
      end

      lex_error('Unterminated string') unless terminated

      # Strip leading and trailing blank lines
      lines = chars.join.lines.map(&:chomp)
      lines = lines.drop_while { _1 =~ /^\s*$/ }
      lines = lines.reverse.drop_while { _1 =~ /^\s*$/ }.reverse
      # Consistent indentation
      left_margin = lines.map do |line|
        line.chars.take_while { _1 == ' ' }.length
      end.min

      lines.map { _1[left_margin..] }.join(LINEFEED)
    end

    def take_while
      chars = []
      chars << consume while yield(lookahead)

      chars
    end

    def seek(n)
      self.index += n
    end

    def consume(str = nil)
      return if str && !match(str)

      c = str || lookahead

      self.index += c.length
      self.column += c.length
      c
    end

    def current_location
      Location.new(lexeme_start_p, current_position)
    end

    def current_position
      Position.new(line, column)
    end

    def next_token
      if punctator = one_of(PUNCTATOR)
        return Token.new(:PUNCTATOR, punctator, current_location)
      end

      if lf = one_of([LINEFEED, "#{CARRIAGE_RETURN}#{LINEFEED}"])
        self.line += 1
        self.column = 1

        return
      end

      c = consume

      return if IGNORED.include?(c)
      return ignore_comment_line if c == COMMENT_CHAR

      return to_token(:NAME)   { name(c)   } if name_start?(c)
      return to_token(:STRING) { string(c) } if string_start?(c)
      return to_token(:NUMBER) { number(c) } if numeric_start?(c)

      lex_error("Unexpected character: #{c.inspect}")
    end

    def string_start?(c)
      c == '"'
    end

    def numeric_start?(c)
      case c
      when '-'
        DIGITS.include?(lookahead)
      when '0'
        !DIGITS.include?(lookahead)
      else
        c != '0' && DIGITS.include?(c)
      end
    end

    def to_token(type)
      i = index - 1
      value = yield
      j = index

      Token.new(type, source[i..j], current_location, value: value)
    end

    def number(c)
      is_negated = c == '-'

      int_part = is_negated ? [] : [c]
      int_part += take_while { digit?(_1) }

      frac_part = fractional_part
      exp_part = exponent_part

      Syntax::NumericLiteral.new(int_part&.join(''), frac_part&.join(''), exp_part, is_negated)
    end

    def fractional_part
      return unless consume('.')

      lex_error("Expected a digit, got #{lookahead}") unless digit?(lookahead)

      take_while { digit?(_1) }
    end

    def exponent_part
      return unless one_of(%w[e E])

      sign = one_of(%w[- +])
      lex_error("Expected a digit, got #{lookahead}") unless digit?(lookahead)

      digits = take_while { digit?(_1) }

      [sign, digits.join]
    end

    def name(c)
      value = [c] + take_while { name_continue?(_1) }

      value.join
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
      take_while { !NEW_LINE.include?(_1) }

      nil
    end
  end
end
