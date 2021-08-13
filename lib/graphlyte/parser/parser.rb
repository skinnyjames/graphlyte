require "strscan"

module Graphlyte
  module Parser
    class Fieldset
      attr_reader :buffer
      def initialize(str, buffer: StringScanner.new(str))
        @buffer = buffer
      end

      def parse
        if buffer.check(/\(/)
          field_name = buffer.scan_until /\(/
          field_name
        end
        [buffer.string, field_name]
      end
    end
    
    class Document 
      attr_reader :buffer

      def initialize(str, buffer: StringScanner.new(str.strip), reverse_buffer: StringScanner.new(str.strip.reverse))
        @buffer = buffer
      end

      def parse_fields
        pp number_of_fieldsets = @buffer.string.scan(/\:.*{|({)/).flatten.reject(&:nil?).size
        search = "(?<=\{)\n.*" * (number_of_fieldsets - 1)

        buffer.skip_until Regexp.new(/\{#{search}\{/)
        token = buffer.rest
        values = token.split("\n").reject do |token|
          token.empty?
        end.map(&:strip)

        i = 0
        while values.include?("}") && i <= number_of_fieldsets
          value = values.pop
          i+=1 if value.eql?("}")
        end

        Fieldset.new(values.join(" ")).parse
      end

    end

    class Parser
      def self.parse(input)
        new(input).get
      end

      attr_reader :buffer

      def initialize(str, buffer: StringScanner.new(str.strip))
        @buffer = buffer
        @type
      end

      def parse_documents
        number_of_documents = @buffer.string.scan(/(?<! )+}/).size
        (0...number_of_documents).to_a.map do 
          Document.new @buffer.scan_until(/(?<! )+}/)
        end
      end

      def get
        parse_documents.map(&:parse_fields)
      end
    end
  end
end
