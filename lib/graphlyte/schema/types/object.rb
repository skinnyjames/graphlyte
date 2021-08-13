module Graphlyte
  module Schema
    module Types
      module FieldArguments
        def parse_of_type(of_type)
          case of_type[:kind]
          when "OBJECT"
            Object.new(of_type[:name])
          end
        end
      end

      class Argument
        def self.from_array(arguments_arr)
          arguments_arr.map do |arg|
            case arg[:type][:kind]
            when "NON_NULL"
              new(NonNull, arg[:name], of_type: arg[:type][:kind][:ofType])
            when "SCALAR"
              new(Scalar, arg[:name])
            when "INPUT_OBJECT"
              new(InputObject, arg[:name])
            when "OBJECT"
              new(Object, arg[:name])
            when "LIST"
              new(List, of_type: nil)
            end
          end
        end

        def initialize(klass, name, of_type: nil)
          @klass = klass
          @name = name
        end
      end

      class Field
        def self.from_array(fields_arr)
          fields_arr.map do |field|
            case field[:type][:kind]
            when "OBJECT"
              new(Object, field[:name]) 
            end
          end
        end

        def initialize(klass, name, of_type: nil)
        end
      end

      class Object < Base
        def initialize(name, fields, description: nil)
          @name = name
          @fields = fields
          @description = description
        end
      end
    end
  end
end