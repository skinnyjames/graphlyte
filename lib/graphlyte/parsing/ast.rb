module Graphlyte
  module Parsing
    module Ast
      class Field
        attr_reader :content, :fieldset
        def initialize(content, fieldset=nil)
          @content = content
          @fieldset = fieldset
        end
      end

      class Content
        attr_reader :value
        def initialize(value)
          @value = value
        end
      end

      class Fieldset
        def initialize(fields=[])
          @fields = fields
        end
      end
    end
  end
end
