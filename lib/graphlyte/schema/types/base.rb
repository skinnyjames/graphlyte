module Graphlyte
  module Schema
    module Types
      class Base
        attr_reader :name, :placeholder

        def initialize(name, placeholder)
          @name = name
          @placeholder = placeholder
        end
      end
    end
  end
end