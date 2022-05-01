# frozen_string_literal: true

require 'rspec/expectations'

class DocDiff
  # delegate :empty?, to: :differences

  class Entry < Struct.new(:path, :msg)
    def to_s
      "(#{path}): #{msg}"
    end
  end

  def initialize(expected, actual)
    @expected = expected.with_inlined_fragments
    @actual = actual.with_inlined_fragments
  end

  def differences
    return @differences if @differences

    @differences = []

    all_names = (@expected.operations.keys + @actual.operations.keys).to_set

    all_names.each do |name|
      if @expected[name] && @actual[name]
        diff_operation(name)
      elsif @expected[name]
        @differences << Entry.new([name], 'Only in expected')
      else
        @differences << Entry.new([name], 'Only in actual')
      end
    end

    def diff_operation(name)
      actual = @actual[name]
      expected = @expected[name]

      return if expected == actual

      diff_attr(:type, [name], expected, actual)
      diff_signatures([name], expected, actual)
      diff_directives([name], expected, actual)
      diff_selection([name], expected, actual)
    end

    def diff_signatures(path, expected, actual)
      path = path + [:variables]
      expected = Array(expected.variables)
      actual = Array(actual.variables)

      diff_non_ordered_collection(:variable, path, expected, actual) do |p, e, a|
        diff_variable_definition(p, e, a)
      end
    end

    def diff_variable_definition(path, expected, actual)
      diff_attr(:type, path, expected, actual)
      diff_attr(:default_value, path, expected, actual)
      diff_directives(path, expected, actual)
    end

    def diff_directives(path, expected, actual)
      path = path + [:directives]
      expected = Array(expected.directives)
      actual = Array(actual.directives)

      diff_non_ordered_collection(:name, path, expected, actual) do |p, e, a|
        diff_arguments(p, e, a)
      end
    end

    def diff_selection(path, expected, actual)
      path = path + [:selection]
      expected = Array(expected.selection)
      actual = Array(actual.selection)

      matched = expected.zip(actual)
      n = matched.length
      only_in_actual = actual.drop(n)

      matched.each_with_index do |(e, a), i|
        if a.nil?
          @differences << Entry.new(path + [i], 'Only in expected')
        else
          diff_selection_node(path + [i], e, a)
        end
      end

      only_in_actual.each_with_index do |a, i|
        @differences << Entry.new(path + [i + n], 'Only in actual')
      end
    end

    def diff_selection_node(path, expected, actual)
      return if actual == expected

      if actual.class != expected.class
        @differences << Entry.new(path, "Expected a #{expected.class}, got a #{actual.class}")
        return
      end

      case expected
      when Graphlyte::Syntax::Field
        diff_field(path, expected, actual)
      when Graphlyte::Syntax::FragmentSpread
        raise 'Fragment not inlined!'
      when Graphlyte::Syntax::InlineFragment
        diff_inline_fragment(path, expected, actual)
      end
    end

    def diff_field(path, expected, actual)
      path = path + [:field]
      diff_attr(:name, path, expected, actual)
      diff_arguments(path, expected, actual)
      diff_directives(path, expected, actual)
      diff_selection(path, expected, actual)
    end

    def diff_inline_fragment(path, expected, actual)
      path = path + [:inline_fragment]
      # TODO
    end

    def diff_arguments(path, expected, actual)
      path = path + [:arguments]
      expected = Array(expected.arguments)
      actual = Array(actual.arguments)

      diff_non_ordered_collection(:name, path, expected, actual) do |p, e, a|
        diff_attr(:value, p, e, a)
      end
    end

    def diff_attr(attr, path, expected, actual)
      a = expected.send(attr)
      b = actual.send(attr)
      return if a == b

      @differences << Entry.new(path + [attr], "#{b} != #{b}")
    end

    def diff_non_ordered_collection(key, path, expected, actual)
      expected = expected.to_h { [_1.send(key), _1] }
      actual = actual.to_h { [_1.send(key), _1] }

      return if expected == actual

      all_names = (expected.keys + actual.keys).to_set

      all_names.each do |name|
        if expected[name] && actual[name]
          yield(path + [name], expected[name], actual[name])
        elsif expected[name]
          @differences << Entry.new(path + [name], 'Only in expected')
        else
          @differences << Entry.new(path + [name], 'Only in actual')
        end
      end
    end
  end
end

RSpec::Matchers.define :parse_like do |str|
  match do |actual|
    @expected = Graphlyte.parse(str)

    actual == @expected
  end

  failure_message do |actual|
    "Expected #{actual} to parse like #{str}"
  end
end

RSpec::Matchers.define :produce_equivalent_document do |str|
  match do |actual|
    @expected = Graphlyte.parse(str)
    @diff = DocDiff.new(@expected, actual)

    @diff.empty?
  end

  failure_message do |actual|
    buff = ['Found the following differences:']
    @diff.differences.each do |difference|
      buff << " - #{difference}"
    end

    buff.join
  end
end
