require "strscan"

module Graphlyte
  class Lexer
    attr_reader :tokens
    def self.tokenize(str)
      new.tokenize(str)
    end

    def tokenize(str)
      str = prepare_string(str)
      buffer = StringScanner.new(str)
      tokens = []
      until buffer.eos?
        if state == :default
          if buffer.scan /\{/
            tokens << [:START_FIELDSET]
          elsif buffer.scan /\}/
            tokens << [:END_FIELDSET]
          elsif buffer.scan /\(/
            tokens << [:START_ARGUMENTS]
            push_state :arguments
          elsif buffer.scan /\s/
            tokens << [:SEPARATOR]
          elsif buffer.scan /[A-Za-z]/m
            tokens << [:CONTENT, buffer.matched]
          end
        elsif state == :arguments
          if buffer.scan /:/
            tokens << [:ARGUMENT_SEPARATOR]
          elsif buffer.scan /\[/
            tokens << [:START_ARRAY_VALUE]
            push_state :array_value
          elsif buffer.scan /\)/
            tokens << [:END_ARGUMENTS]
            pop_state
          elsif buffer.scan /\{/
            tokens << [:START_OBJECT_VALUE]
            push_state :object_value
          elsif buffer.scan /\w/m
            tokens << [:CONTENT, buffer.matched]
          elsif buffer.scan /,/
            tokens << [:ARGUMENT_VALUE_SEPARATOR]
          elsif buffer.scan /\s/
            # do nothing
          end
        elsif state == :array_value
          if buffer.scan /\]/
            tokens << [:END_ARRAY_VALUE]
            pop_state
          elsif buffer.scan /,/
            tokens << [:ARRAY_SEPARATOR]
          elsif buffer.scan /\w/
            tokens << [:CONTENT, buffer.matched]
          end
        elsif state == :object_value
          if buffer.scan /\}/
            tokens << [:END_OBJECT_VALUE]
            pop_state
          elsif buffer.scan /,/
            tokens << [:OBJECT_SEPARATOR]
          elsif buffer.scan /:/
            tokens << [:ARGUMENT_SEPARATOR]
          elsif buffer.scan /\{/
            tokens << [:START_OBJECT_VALUE]
            push_state :object_value
          elsif buffer.scan /\[/
            tokens << [:START_ARRAY_VALUE]
            push_state :array_value
          elsif buffer.scan /\w/
            tokens << [:CONTENT, buffer.matched]
          elsif buffer.scan /\s/
          end
        end
      end
      tokens
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
      str.split("").inject([]) do |memo, f|
        memo << f unless (f =~ /\s/ && memo[-1] =~ /\s/)
        memo
      end.join("")
    end
  end
end
