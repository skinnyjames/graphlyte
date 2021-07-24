require "strscan"
module Graphlyte
  module Parsing
    class Lexer
      attr_accessor :tokens
      attr_reader :buffer
      def self.tokenize(str)
        new(str).tokenize
      end

      def initialize(str)
        @buffer = StringScanner.new(prepare_string(str))
        @tokens = []
      end
  
      def tokenize
        until buffer.eos?
          char = buffer.getch
          if state == :default
            parse_default(char)
          elsif state == :arguments
            parse_arguments(char)
          elsif state == :string_value
            parse_string(char)          
          elsif state == :object
            parse_object(char)
          elsif state == :array_value
            parse_array(char)
          elsif state == :object_value
            parse_object_value(char)
          end
        end
        tokens
      end

      def parse_default(char)
        if char =~ /\{/
          tokens << [:START_FIELDSET]
        elsif char =~ /\}/
          tokens << [:END_FIELDSET]
        elsif char =~ /\(/
          tokens << [:START_ARGUMENTS]
          push_state :arguments
        elsif char =~ /\s/
          tokens << [:SEPARATOR]
        elsif char =~ /\"/
          push_state :string_value
        elsif char =~ /[A-Za-z]/m
          if str = buffer.scan_until(/[^A-Za-z]/)
            char += str[0..-2]
            buffer.pos = (buffer.pos - 1)
          end
          if (integer(char) rescue false)
            char = char.to_i
          end
          tokens << [:CONTENT, char]
        end
      end

      def parse_arguments(char)
        if char =~ /:/
          tokens << [:ARGUMENT_SEPARATOR]
        elsif char =~ /\[/
          tokens << [:START_ARRAY_VALUE]
          push_state :array_value
        elsif char =~ /\)/
          tokens << [:END_ARGUMENTS]
          pop_state
        elsif char =~ /\{/
          tokens << [:START_OBJECT_VALUE]
          push_state :object
        elsif char =~ /\w/m
          if str = buffer.scan_until(/[^A-Za-z]/)
            char += str[0..-2]
            buffer.pos = (buffer.pos - 1)
          end
          tokens << [:CONTENT, char]
        elsif char =~ /,/
          tokens << [:ARGUMENT_VALUE_SEPARATOR]
        elsif char =~ /\s/
          # do nothing
        end
      end

      def parse_string(char)
        if char =~ /\"/
          pop_state
        elsif char =~ /.*/m
          if str = buffer.scan_until(/[^A-Za-z]/)
            char += str[0..-2]
            buffer.pos = (buffer.pos - 1)
          end
          tokens << [:CONTENT, char]
        end
      end

      def parse_array(char)
        if char =~ /\]/
          tokens << [:END_ARRAY_VALUE]
          pop_state
        elsif char =~ /,/
          tokens << [:ARRAY_SEPARATOR]
        elsif char =~ /\w/
          if str = buffer.scan_until(/[^A-Za-z]/)
            char += str[0..-2]
            buffer.pos = (buffer.pos - 1)
          end
          tokens << [:CONTENT, char]
        end
      end

      def parse_object(char)
        if char =~ /,/
          tokens << [:OBJECT_SEPARATOR]
        elsif char =~ /:/
          tokens << [:ARGUMENT_SEPARATOR]
        elsif char =~ /\{/
          tokens << [:START_OBJECT_VALUE]
          push_state :object
        elsif char =~ /\[/
          tokens << [:START_ARRAY_VALUE]
          push_state :array_value
        elsif char =~ /\w/
          if str = buffer.scan_until(/[^A-Za-z]/)
            char += str[0..-2]
            buffer.pos = (buffer.pos - 1)
          end
          tokens << [:CONTENT, char]
        elsif char =~ /\s/
        end 
      end
  
      def stack
        @stack ||= []
      end
      
      def state
        stack.last || :default
      end
      
      def push_state(state)
        stack.push(state)
      end
      
      def pop_state
        stack.pop
      end
  
      def prepare_string(str)
        str = str.split("").inject([]) do |memo, f|
          memo << f unless (f =~ /\s/ && (memo[-1] =~ /\s/))
          memo
        end.join("")
        str.gsub!(/\{\s/, "{")
        str.gsub!(/\s\{/, "{")
        str.gsub!(/\s\}/, "}")
        str.gsub!(/\}\s/, "}")
      end
    end
  end
end