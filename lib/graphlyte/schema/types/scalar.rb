module Graphlyte
  module Schema
    module Types

      class Scalar < Base
        def initialize(name)
          @name = name
        end

        def to_class(value)
          case name
          when "ID"
            nil
          when "String"
            value.to_s
          when "Int"
            value.to_i
          when "Boolean"
            value.to_f
          end
        end

        def class
          case name
          when "ID"
            nil
          when "String"
            [String]
          when "Int"
            [Integer]
          when "Boolean"
            [TrueClass, FalseClass]
          end            
        end
      end
    end
  end
end