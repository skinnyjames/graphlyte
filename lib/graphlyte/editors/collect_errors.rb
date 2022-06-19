# frozen_string_literal: true

module Graphlyte
  module Editors
    # Editor to collect errors
    # from Syntax tree objects
    class CollectErrors
      attr_reader :errors

      def initialize
        @errors = []
      end

      def unique_errors
        errors.uniq
      end

      def edit(doc)
        handle_errors(doc, Struct.new(:path).new([Struct.new(:name).new('document')]))

        editor.edit(doc)

        self
      end

      def editor
        Editor
          .top_down
          .on_operation(&method(:handle_errors))
          .on_fragment(&method(:handle_errors))
          .on_fragment_spread(&method(:handle_errors))
          .on_field(&method(:handle_errors))
          .on_argument(&method(:handle_errors))
          .on_input_object(&method(:handle_errors))
          .on_value(&method(:handle_errors))
      end

      def handle_errors(syntax, context)
        return unless syntax.errors.any?

        paths = context.path.reject { |path| path.instance_of?(Syntax::InputObject) }

        path = paths.map do |obj|
          case obj
          when Syntax::Value
            case obj.value
            when Syntax::Literal, Symbol
              obj.value.to_s
            else
              obj.value
            end
          else
            obj.respond_to?(:name) ? (obj.name || obj.type_name) : obj.type_name
          end
        end

        mapped_error = syntax.errors.map do |error|
          {
            message: error,
            path: path
          }
        end

        errors.concat(mapped_error)
      end
    end
  end
end
