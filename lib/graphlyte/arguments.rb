module Graphlyte
  class Arguments
    def initialize(data)
      @data = data
    end
    
    def to_s
      return @data && !@data.empty? ? "(#{@data.map{|k, v| "#{k}: \"#{v}\""}.join(", ")})" : ""
    end
  end
end