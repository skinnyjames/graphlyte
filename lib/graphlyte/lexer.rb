# frozen_string_literal: true

require 'forwardable'

require_relative './lexing/token'
require_relative './lexing/location'

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

  # A terminal production. May or may not produce a lexical token.
  class Production
    attr_reader :token

    def initialize(token)
      @token = token
    end
  end

  # Transform a string into a stream of tokens - i.e. lexing
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

    attr_reader :source, :tokens
    attr_accessor :line, :column, :index, :lexeme_start_p

    def initialize(source)
      @source = source
      @tokens = []
      @line = 1
      @column = 1
      @index = 0
      @lexeme_start_p = Lexing::Position.new(0, 0)
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

      tokens << Lexing::Token.new(:EOF, nil, after_source_end_location)
    end

    private

    def after_source_end_location
      Lexing::Location.eof
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

    def string
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
      while (char = string_character)
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
      when 'u' then hex_char
      else
        lex_error("Unexpected escaped character in string: #{c}")
      end
    end

    def hex_char
      char_code = [1, 2, 3, 4].map do
        d = consume
        hex_digit = (digit?(d) || ('a'...'f').cover?(d.downcase))
        lex_error("Expected a hex digit in unicode escape sequence. Got #{d.inspect}") unless hex_digit

        d
      end

      char_code.join.hex.chr
    end

    def block_string_content
      chars = []
      terminated = false

      until eof? || (terminated = consume(BLOCK_QUOTE))
        chars << BLOCK_QUOTE if consume("\\#{BLOCK_QUOTE}")
        chars << '"' while consume(DOUBLE_QUOTE)
        while (char = string_character(block_string: true))
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

    def seek(offset)
      self.index += offset
    end

    def consume(str = nil)
      return if str && !match(str)

      c = str || lookahead

      self.index += c.length
      self.column += c.length
      c
    end

    def current_location
      Lexing::Location.new(lexeme_start_p, current_position)
    end

    def current_position
      Lexing::Position.new(line, column)
    end

    def next_token
      (punctator || skip_line || lexical_token).token
    end

    def punctator
      p = one_of(PUNCTATOR)

      Production.new(Lexing::Token.new(:PUNCTATOR, p, current_location)) if p
    end

    def skip_line
      lf = one_of([LINEFEED, "#{CARRIAGE_RETURN}#{LINEFEED}"])
      return unless lf

      next_line!
      Production.new(nil)
    end

    def lexical_token
      c = consume
      t = if IGNORED.include?(c)
            nil
          elsif c == COMMENT_CHAR
            ignore_comment_line
          elsif name_start?(c)
            to_token(:NAME)   { name(c)   }
          elsif string_start?(c)
            to_token(:STRING) { string    }
          elsif numeric_start?(c)
            to_token(:NUMBER) { number(c) }
          else
            lex_error("Unexpected character: #{c.inspect}")
          end

      Production.new(t)
    end

    def next_line!
      self.line += 1
      self.column = 1
    end

    def string_start?(char)
      char == '"'
    end

    def numeric_start?(char)
      case char
      when '-'
        DIGITS.include?(lookahead)
      when '0'
        !DIGITS.include?(lookahead)
      else
        char != '0' && DIGITS.include?(char)
      end
    end

    def to_token(type)
      i = index - 1
      value = yield
      j = index

      Lexing::Token.new(type, source[i..j], current_location, value: value)
    end

    def number(char)
      is_negated = char == '-'

      int_part = is_negated ? [] : [char]
      int_part += take_while { digit?(_1) }

      frac_part = fractional_part
      exp_part = exponent_part

      Syntax::NumericLiteral.new(integer_part: int_part&.join(''),
                                 fractional_part: frac_part&.join(''),
                                 exponent_part: exp_part,
                                 negated: is_negated)
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

    def name(char)
      value = [char] + take_while { name_continue?(_1) }

      value.join
    end

    def name_start?(char)
      letter?(char) || underscore?(char)
    end

    def name_continue?(char)
      letter?(char) || digit?(char) || underscore?(char)
    end

    def letter?(char)
      LETTERS.include?(char)
    end

    def underscore?(char)
      char == '_'
    end

    def digit?(char)
      DIGITS.include?(char)
    end

    def ignore_comment_line
      take_while { !NEW_LINE.include?(_1) }

      nil
    end
  end
end
