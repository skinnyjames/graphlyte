require_relative "schema/types/base"
require_relative "schema/types/enum"
require_relative "schema/types/input_object"
require_relative "schema/types/interface"
require_relative "schema/types/list"
require_relative "schema/types/non_null"
require_relative "schema/types/object"
require_relative "schema/types/scalar"
require_relative "schema/types/union"


module Graphlyte
  class Types
    def method_missing(method, placeholder)
      Schema::Types::Base.new(method, placeholder)
    end

    def ID(placeholder)
      Schema::Types::Scalar.new("ID", placeholder)
    end
    
    def ID!(placeholder)
      Schema::Types::Scalar.new("ID!", placeholder)
    end

    def INPUT_OBJECT(type, placeholder)
      Schema::Types::InputObject.new(type, placeholder)
    end
  end
end