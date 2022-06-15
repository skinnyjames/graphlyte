# frozen_string_literal: true

module Graphlyte
  module Editors
    class CollectErrors
      attr_reader :errors

      def initialize
        @errors = []
      end

      def edit(doc)
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
      end

      def handle_errors(syntax, context)
        return unless syntax.errors.any?

        path = context.path.map do |syntax|
          syntax.respond_to?(:name) ? syntax.name : syntax.type_name
        end

        errors << <<~ERROR
          Error on #{readable_path(path)}\n-----\n#{readable_errors(syntax.errors)}

        ERROR
      end

      def readable_errors(errors)
        errors.each_with_index.map { |e, i| "#{i + 1} #{e}" }.join("\n")
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