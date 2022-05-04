# frozen_string_literal: true

require_relative '../editor'
require_relative '../syntax'

module Graphlyte
  module Editors
    # Reduce a document down to a single operation, removing unnecessary fragments
    #
    # eg:
    #
    #   pry(main)> puts doc
    #
    #   query A {
    #     foo(bar: $baz) {
    #       ...foos
    #     }
    #   }
    #
    #   fragment foos on Foo {
    #     a
    #     b
    #     ...bars
    #   }
    #
    #   fragment bars on Foo { d e f }
    #
    #   query B {
    #     foo {
    #       ...bars
    #     }
    #   }
    #
    #   pry(main)> puts Graphlyte::Editors::SelectOperation.new('A').edit(doc.dup)
    #
    #   query A {
    #     foo(bar: $baz) {
    #       ...foos
    #     }
    #   }
    #
    #   fragment foos on Foo {
    #     a
    #     b
    #     ...bars
    #   }
    #
    #   fragment bars on Foo { d e f }
    #
    #   pry(main)> puts Graphlyte::Editors::SelectOperation.new('B').edit(doc.dup)
    #
    #   fragment bars on Foo { d e f }
    #
    #   query B {
    #     foo {
    #       ...bars
    #     }
    #   }
    #
    class SelectOperation
      def initialize(operation)
        @operation = operation
      end

      def edit(doc)
        to_keep = build_fragment_tree(doc)[@operation]

        doc.definitions.select! do |definition|
          case definition
          when Syntax::Operation
            definition.name == @operation
          else
            to_keep.include?(definition.name)
          end
        end

        doc
      end

      # Compute the transitive closure of fragments used in each operation.
      def build_fragment_tree(doc)
        names_per_op = {}
        names_per_fragment = {}

        collect = Editor.new.on_fragment_spread do |spread, action|
          set = case action.definition
                when Syntax::Operation
                  names_per_op[action.definition.name] ||= [].to_set
                else
                  names_per_fragment[action.definition.name] ||= [].to_set
                end

          set << spread.name
        end

        collect.edit(doc)

        names_per_op.each do |op_name, spreads|
          unvisited = spreads.to_a

          until unvisited.empty?
            names_per_fragment[unvisited.pop]&.each do |name|
              next if spreads.include?(name)

              spreads << name
              unvisited << name
            end
          end
        end

        names_per_op
      end
    end
  end
end
