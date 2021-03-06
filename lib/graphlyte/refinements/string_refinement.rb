# frozen_string_literal: true

module Graphlyte
  module Refinements
    # Adds `camelize` methods to `Symbol` and `String`.
    module StringRefinement
      refine Symbol do
        def camelize
          to_s.camelize
        end
      end

      refine String do
        def camelize
          return self if match(/^_*$/)

          start_of_string = match(/(^_+)/)&.[](0)
          end_of_string = match(/(_+$)/)&.[](0)

          middle = split('_').reject(&:empty?).inject([]) do |memo, str|
            memo << (memo.empty? ? str : str.capitalize)
          end.join

          "#{start_of_string}#{middle}#{end_of_string}"
        end
      end
    end
  end
end
