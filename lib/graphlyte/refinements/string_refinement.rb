module Graphlyte
  module Refinements
    module StringRefinement
      refine Symbol do 
        def to_camel_case
          to_s.to_camel_case
        end
      end
      refine String do 
        def to_camel_case
          start_of_string = match(/(^_+)/)&.[](0)
          end_of_string = match(/(_+$)/)&.[](0)
      
          middle = split("_").reject(&:empty?).inject([]) do |memo, str|
            memo << (memo.empty? ? str : str.capitalize)
          end.join("")
        
          "#{start_of_string}#{middle}#{end_of_string}"
        end 
      end
    end
  end
end
