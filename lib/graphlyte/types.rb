require_relative "schema/types/base"

module Graphlyte
  class Types
    def method_missing(method, placeholder)
      Schema::Types::Base.new(method, placeholder)
    end
  end
end