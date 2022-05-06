describe Graphlyte do 
  it "supports variables, as variable objects" do 
    bar = Graphlyte.var('Int', 'bar')
    foo = Graphlyte.var('String', 'foo')

    query = Graphlyte.query do
      arguments(foo: bar, bar: foo) do
        id
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    query ($foo: String, $bar: Int) {
      arguments(foo: $bar, bar: $foo) {
        id
      }
    }
    STRING
  end

  it "supports variables, using symbols" do 
    query = Graphlyte.query do
      arguments(foo: :bar) do
        id
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    query {
      arguments(foo: $bar) {
        id
      }
    }
    STRING
  end

  it "should support integers" do 
    query = Graphlyte.query do
      arguments(int: 1) do
        id
      end 
    end
    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(int: 1) {
        id
      }
    }
    STRING
  end

  it "should support floats" do 
    query = Graphlyte.query do |q|
      q.arguments(float: 1.01) do |i|
        i.id
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(float: 1.01) {
        id
      }
    }
    STRING
  end

  it "should support exponentiation" do 
    query = Graphlyte.query do |q|
      q.arguments(big: 1_000_000) do |i|
        i.id
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(big: 1e6) {
        id
      }
    }
    STRING
  end

  it "should support exponentiation, negative" do 
    query = Graphlyte.query do |q|
      q.arguments(small: 0.000001) do |i|
        i.id
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(small: 1e-6) {
        id
      }
    }
    STRING
  end

  it "should support strings" do 
    query = Graphlyte.query do |q|
      q.arguments(string: "hello")
    end
    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(string: "hello")
    }
    STRING
  end

  it "should support lists" do 
    query = Graphlyte.query do |q|
      q.arguments(list: [1, 2])
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(list: [1, 2])
    }
    STRING
  end

  it "should support hashes" do 
    query = Graphlyte.query do
      arguments(object: { one: 2, three: [1, 2] })
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      arguments(object: { one: 2, three: [1, 2] })
    }
    STRING
  end

  it "should handle booleans" do 
    query = Graphlyte.query do
      foo(boolean: true)
      bar(boolean: false)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
    {
      foo(boolean: true)
      bar(boolean: false)
    }
    STRING
  end
end
