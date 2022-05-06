# frozen_string_literal: true

module Graphlyte
  module Refinements
    module SyntaxRefinements
      refine Hash do
        def to_input_value
          transform_keys(&:to_s).transform_values(&:to_input_value)
        end
      end

      refine Array do
        def to_input_value
          map(&:to_input_value)
        end
      end

      refine String do
        def to_input_value
          Syntax::Value.new(self, :STRING)
        end
      end

      refine Symbol do
        def to_input_value
          Syntax::Value.new(self, :ENUM)
        end
      end

      refine Integer do
        def to_input_value
          Syntax::Value.new(self, :NUMBER)
        end
      end

      refine Float do
        def to_input_value
          Syntax::Value.new(self, :NUMBER)
        end
      end

      refine TrueClass do
        def to_input_value
          Syntax::Value.new(Syntax::TRUE, :BOOL)
        end
      end

      refine FalseClass do
        def to_input_value
          Syntax::Value.new(Syntax::FALSE, :BOOL)
        end
      end

      refine NilClass do
        def to_input_value
          Syntax::Value.new(Syntax::NULL, :NULL)
        end
      end
    end
  end
end
