# frozen_string_literal: true

describe Graphlyte do
  it 'supports variables, as variable objects' do
    bar = Graphlyte.var('Int', 'bar')
    foo = Graphlyte.var('String', 'foo')

    query = Graphlyte.query do |q|
      q.arguments(foo: bar, bar: foo)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      query ($foo: String, $bar: Int) {
        arguments(foo: $bar, bar: $foo)
      }
    STRING
  end

  it 'supports variables, using symbols' do
    query = Graphlyte.query do |q|
      q.arguments(foo: :bar)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      query {
        arguments(foo: $bar)
      }
    STRING
  end

  it 'should support integers' do
    query = Graphlyte.query do |q|
      q.arguments(int: 1)
    end
    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(int: 1)
      }
    STRING
  end

  it 'should support floats' do
    query = Graphlyte.query do |q|
      q.arguments(float: 1.01, &:id)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(float: 1.01) {
          id
        }
      }
    STRING
  end

  it 'should support exponentiation' do
    query = Graphlyte.query do |q|
      q.arguments(big: 1_000_000, &:id)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(big: 1e6) {
          id
        }
      }
    STRING
  end

  it 'should support exponentiation, negative' do
    query = Graphlyte.query do |q|
      q.arguments(small: 0.000001, &:id)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(small: 1e-6) {
          id
        }
      }
    STRING
  end

  it 'should support strings' do
    query = Graphlyte.query do |q|
      q.arguments(string: 'hello')
    end
    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(string: "hello")
      }
    STRING
  end

  it 'should support lists' do
    query = Graphlyte.query do |q|
      q.arguments(list: [1, 2])
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(list: [1, 2])
      }
    STRING
  end

  it 'should support hashes' do
    query = Graphlyte.query do |q|
      q.arguments(object: { one: 2, three: [1, 2] })
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        arguments(object: { one: 2, three: [1, 2] })
      }
    STRING
  end

  it 'should handle booleans' do
    query = Graphlyte.query do |q|
      q.foo(boolean: true)
      q.bar(boolean: false)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        foo(boolean: true)
        bar(boolean: false)
      }
    STRING
  end
end
