require "strscan"
# module Graphlyte
#   module NewParser

#     module Collectable
#       def <<(token)
#       end
#     end

#     class TokenCollection
#       include Enumerable

#       attr_reader :collection

#       def initialize(collection=[], started: false)
#         @collection = collection
#         @started = started
#         @ended = false
#       end

#       def <<(item)
#         @collection.push(item)
#       end

#       def each
#         @collection.each do |item|
#           yield item
#         end
#       end
#     end

#     class ArgumentCollection < TokenCollection
    
#     end
    
    
#     class FieldsetCollection < TokenCollection
#       def in_progress?
#         starts = select(&:start_fieldset?)
#         ends = select(&:end_fieldset?)
#         starts.size.eql? ends.size
#       end
#     end
#     class QueryCollection < TokenCollection; end

    

#     class Parser
#       def self.parse(input)
#         new(input).get
#       end
#       attr_reader :buffer

#       def initialize(str, buffer: StringScanner.new(str.gsub(/\s/, "")))
#         @buffer = buffer
#         @top_level_collections = []
#       end

#       def get
#         token = Token.new(buffer.getch, top_level: true)
#         if token.start_fieldset?
#           collection = FieldsetCollection.new(started: true)
#           collection << token
#           while collection.in_progress?
#             collection << Token.new(buffer.getch)
#           end
#           collection.to_a.reverse
#         end
#       end
#     end
#   end
# end
module Graphlyte
  START_FIELDSET_OR_OBJECT = "{"
  END_FIELDSET_OR_OBJECT = "}"
  START_INPUT = "("
  END_INPUT = ")"

  START_MUTATION = "m"
  START_QUERY = "q"
  START_FRAGMENT = "f"

  class Token
    attr_reader :char
    def initialize(char, top_level: false)
      @char = char
      @top_level = top_level
    end

    def top?
      @top_level
    end

    def word?
      char =~ /[a-zA-Z]/
    end

    def valid?
      [START_FIELDSET_OR_OBJECT, START_QUERY, START_FRAGMENT].include? char
    end

    def start_fieldset?
      char.eql? START_FIELDSET_OR_OBJECT
    end

    def end_fieldset?
      char.eql? END_FIELDSET_OR_OBJECT
    end

    def start_query?
      char.eql? START_QUERY
    end

    def start_fragment?
      char.eql? START_FRAGMENT
    end
  end

  class FieldsetToken
    attr_reader :key, :value
    def initialize(key, value)
      @key = key
      @value = value
    end
  end

  class FieldsetTokenCollection
    include Enumerable
    def initialize
      @fields = []
    end

    def each 
      @fields.each do |item|
        yield item
      end
    end
    def <<(field)
      @fields << field
    end
  end

  class NewParser
    def self.parse(input)
      new(input).get_all
    end
    attr_reader :buffer

    def initialize(str)
      new_string = str.gsub(/\s/, ">")
      new_string = new_string.split("").inject([]) do |memo, f|
        memo << f unless f.eql?(">") && memo[-1].eql?(">") 
        memo
      end.join("")
      pp new_string
      @buffer = StringScanner.new(new_string)
      @top_level_collections = []
    end

    def get_all(fields = FieldsetTokenCollection.new, parent=nil)
      return fields if buffer.eos?
      char = buffer.getch
      if char =~ /[a-zA-Z]/
        word = buffer.scan_until /[^a-zA-Z]/
        last = word[-1]
        word.chop!
        word = char + word

        field = FieldsetToken.new(word, FieldsetTokenCollection.new)
        if last.eql?(">")
          fields << field
          get_all(fields, parent)
        end
        buffer.pos = (buffer.pos - 1)
        buffer.check(/[a-zA-Z]/) ? get_all(fields, field) : get_all(field.value, field)

      elsif char.eql? START_FIELDSET_OR_OBJECT
        field = FieldsetToken.new("{", FieldsetTokenCollection.new)
        get_all(fields, field)
      elsif char.eql? END_FIELDSET_OR_OBJECT
      elsif char.eql? ">"
        get_all(fields)
      end
      fields
    end

    def get(fields = {}, parent=nil)
      return fields if buffer.eos?
      char = buffer.getch
      if char =~ /[a-zA-Z]/
        word = buffer.scan_until /[^a-zA-Z]/
        last = word[-1]
        word.chop!
        if last.eql?("\n")
          fields[char + word] = []
        else
          fields[char + word] = {}
        end
        buffer.pos = (buffer.pos - 1)
        buffer.check(/[a-zA-Z]/) ? get(fields) : get(fields[char + word], fields)
      elsif char.eql? START_FIELDSET_OR_OBJECT
        get(fields)
      elsif char.eql? END_FIELDSET_OR_OBJECT
        get(parent)
      end
      fields
    end
  end
end