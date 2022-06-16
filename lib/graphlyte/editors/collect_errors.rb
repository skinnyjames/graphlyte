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
          .on_value(&method(:handle_errors))
      end

      def handle_errors(syntax, context)
        return unless syntax.errors.any?

        paths = context.path.reject { |path| path.instance_of?(Syntax::InputObject) }

        path = paths.map do |obj|
          case obj
          when Syntax::Value
            obj.value
          else
            obj.respond_to?(:name) ? (obj.name || obj.type_name) : obj.type_name
          end
        end

        errors << <<~ERROR
          Error on #{readable_path(path)}\n#{readable_errors(syntax.errors)}
        ERROR
      end

      def readable_errors(errors)
        errors.each_with_index.map { |e, i| "#{i + 1}.) #{e}" }.join("\n")
      end

      def readable_path(path, str = [], space = 0)
        return str.join("\n") if path.empty?

        name = path.shift
        str << "#{' ' * space}#{name}"

        readable_path(path, str, space + 2)
      end
    end
  end
end
