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
    DOUBLE_QUOTE = '"'
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

    class NumericLiteral
      attr_reader :integer_part, :fractional_part, :exponent_part, :negated

      def initialize(integer_part, fractional_part, exponent_part, negated)
        @integer_part = integer_part
        @fractional_part = fractional_part
        @exponent_part = exponent_part
        @negated = negated
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
    
    def string(c)
      i = index - 1

      content = if lookahead == DOUBLE_QUOTE && lookahead(2) != DOUBLE_QUOTE
        consume
        '' # The empty string
      elsif match('""') # Block string
        block_string_content
      else
        string_content
      end

      j = index
      src = source[i...j]

      Token.new(:STRING, src, current_location, literal: content)
    end

    def string_content
      chars = []
      while char = string_character
        chars << char
      end

      lex_error('Unterminated string') unless consume(DOUBLE_QUOTE)

      chars.join('')
    end

    def string_character
      return if lookahead == DOUBLE_QUOTE

      c = consume

      lex_error("Illegal character #{c.inspect}") if NEW_LINE.include?(c)

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
      when 'u' then
        char_code = [1, 2, 3, 4].map do
          d = consume
          hex_digit = (digit?(d) || ('a' ... 'f').cover?(d.downcase))
          lex_error("Expected a hex digit in unicode escape sequence. Got #{d.inspect}") unless hex_digit

          d
        end

        char_code.join('').hex.chr
      else
        lex_error("Unexpected escaped character in string: #{c}")
      end
    end

    def block_string_content
      lex_error('Unterminated string') unless consume(BLOCK_QUOTE)
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

    def tokenize
      self.lexeme_start_p = current_position

      token = next_token

      tokens << token if token
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

      return name(c) if name_start?(c)
      return string(c) if string_start?(c)
      return number(c) if numeric_start?(c)

      lex_error("Unexpected character: #{c.inspect}")
    end

    def string_start?(c)
      '"' == c
    end

    def numeric_start?(c)
      if '-' == c
        DIGITS.include?(lookahead) 
      else
        c != '0' && DIGITS.include?(c)
      end
    end

    def number(c)
      i = index - 1

      is_negated = c == '-'

      int_part = is_negated ? [] : [c]
      int_part += take_while { digit?(_1) }

      frac_part = fractional_part
      exp_part = exponent_part

      j = index

      value = NumericLiteral.new(int_part, frac_part, exp_part, is_negated)
      str = source[i..j]

      Token.new(:NUMBER, str, current_location, literal: value) 
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

      [sign, digits]
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
      take_while { !NEW_LINE.include?(_1) }

      :skip
    end
  end
end
