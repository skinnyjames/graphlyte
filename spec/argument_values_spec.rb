describe Graphlyte do 
  it "should support integers" do 
    query = Graphlyte.query do
      arguments(int: 1) do
        id
      end 
    end
    expect(query.to_s).to eql(<<~STRING)
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
    expect(query.to_s).to eql(<<~STRING)
    {
      arguments(float: 1.01) {
        id
      }
    }
    STRING
  end

  it "should support strings" do 
    query = Graphlyte.query do |q|
      q.arguments(string: "hello") do |i|
        i.id
      end 
    end
    expect(query.to_s).to eql(<<~STRING)
    {
      arguments(string: "hello") {
        id
      }
    }
    STRING
  end

  it "should support lists" do 
    query = Graphlyte.query do |q|
      q.arguments(list: [1, 2, "string"]) do |i|
        i.id
      end 
    end
    expect(query.to_s).to eql(<<~STRING)
    {
      arguments(list: [1, 2, "string"]) {
        id
      }
    }
    STRING
  end

  it "should support hashes" do 
    query = Graphlyte.query do |q|
      q.arguments(object: { one: 2, three: [1, 2] }) do |i|
        i.id
      end 
    end
    expect(query.to_s).to eql(<<~STRING)
    {
      arguments(object: { one: 2, three: [1, 2] }) {
        id
      }
    }
    STRING
  end

  it "should handle booleans" do 
    query = Graphlyte.query do |q|
      q.arguments(boolean: true) do |i|
        i.id
      end 
    end
    expect(query.to_s).to eql(<<~STRING)
    {
      arguments(boolean: true) {
        id
      }
    }
    STRING
  end
end