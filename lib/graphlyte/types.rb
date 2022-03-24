require_relative "schema/types/base"

module Graphlyte
  class Types
    def method_missing(method, placeholder, default = nil)
      Schema::Types::Base.new(method, placeholder, default)
    end
  end
end