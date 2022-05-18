# frozen_string_literal: true

require 'rspec/expectations'

class DocDiff
  # delegate :empty?, to: :differences

  Entry = Struct.new(:path, :msg) do
    def to_s
      "(#{path.join('.')}): #{msg}"
    end
  end

  def initialize(expected, actual)
    canonicalize = Graphlyte::Editors::Canonicalize.new

    @expected_fragment_names = expected.fragments.keys
    @actual_fragment_names = actual.fragments.keys
    @expected = canonicalize.edit(expected)
    @actual = canonicalize.edit(actual)
  end

  def empty?
    differences.empty?
  end

  def differences
    return @differences if @differences

    @differences = []

    # Ignore fragments - they are inlined during canonicalization.
    diff_operations
    diff_fragment_names # do we care? Not sure...

    @differences
  end

  private

  def diff_operations
    operations = diff_merge(@expected.operations, @actual.operations)

    operations.each do |name, (e, a)|
      if e && a
        diff_operation(name, e, a)
      else
        only_in([name || '<ANON>'], e)
      end
    end
  end

  def diff_fragment_names
    expected = @expected_fragment_names.to_set
    actual = @actual_fragment_names.to_set
    return if expected == actual

    (expected - actual).each do |name|
      @differences << Entry.new([:fragments, name], 'Only in expected')
    end

    (actual - expected).each do |name|
      @differences << Entry.new([:fragments, name], 'Only in actual')
    end
  end

  def diff_operation(name, expected, actual)
    return if expected == actual

    path = [name || '<ANON>']
    diff_attr(:type, path, expected, actual)
    diff_signatures(path, expected, actual)
    diff_directives(path, expected, actual)
    diff_selection(path, expected, actual)
  end

  def diff_signatures(path, expected, actual)
    path += %i[signature variables]
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
    path += [:directives]
    expected = Array(expected.directives)
    actual = Array(actual.directives)

    diff_non_ordered_collection(:name, path, expected, actual) do |p, e, a|
      diff_arguments(p, e, a)
    end
  end

  def diff_selection(path, expected, actual)
    path += [:selection]
    matched = diff_zip(expected.selection, actual.selection)

    matched.each_with_index do |(e, a), i|
      if e && a
        diff_selection_node(path + [i], e, a)
      else
        only_in(path + [i], e)
      end
    end
  end

  def diff_selection_node(path, expected, actual)
    return if actual == expected
    return if diff_attr(:class, path, expected, actual)

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
    path += [:field]
    diff_attr(:name, path, expected, actual)
    diff_arguments(path, expected, actual)
    diff_directives(path, expected, actual)
    diff_selection(path, expected, actual)
  end

  def diff_inline_fragment(path, expected, actual)
    path += [:inline_fragment]
    diff_attr(:type_name, path, expected, actual)
    diff_directives(path, expected, actual)
    diff_selection(path, expected, actual)
  end

  def diff_arguments(path, expected, actual)
    path += [:arguments]
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

    @differences << Entry.new(path + [attr], "#{a.inspect} != #{b.inspect}")
  end

  def diff_non_ordered_collection(key, path, expected, actual)
    expected = index_on(key, expected)
    actual = index_on(key, actual)

    diff_merge(expected, actual).each do |name, (e, a)|
      if e && a
        yield(path + [name], e, a)
      else
        only_in(path + [name], e)
      end
    end
  end

  # Merge two hashes, so each value is a two-tuple `[left[key], right[key]]`
  def diff_merge(left, right)
    lefts = left.transform_values { [_1, nil] }
    rights = right.transform_values { [nil, _1] }
    lefts.merge(rights) { |_k, l, r| [l.first, r.last] }
  end

  def index_on(key, collection)
    collection.to_h { [_1.send(key), _1] }
  end

  # Merge two arrays (or nils), returning tuples: `[lefts[i], rights[i]]`
  def diff_zip(lefts, rights)
    lefts = Array(lefts)
    rights = Array(rights)
    matched = lefts.zip(rights)

    matched + rights.drop(matched.length).map { [nil, _1] }
  end

  def only_in(path, expected)
    @differences << Entry.new(path, expected ? 'Only in expected' : 'Only in actual')
  end
end

RSpec::Matchers.define :be_equivalent_to do |expected|
  match do |actual|
    @diff = DocDiff.new(expected, actual)

    @diff.empty?
  end

  failure_message do |actual|
    buff = [
      'Queries do not match! Got:',
      actual.to_s,
      'Found the following differences:'
    ]

    @diff.differences.each do |difference|
      buff << " - #{difference}"
    end

    buff.join("\n")
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
    buff = [
      'Queries do not match! Got:',
      actual.to_s,
      'Found the following differences:'
    ]

    @diff.differences.each do |difference|
      buff << " - #{difference}"
    end

    buff.join("\n")
  end
end
