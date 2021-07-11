describe Graphlyte do 
  it "should not expose method_missing on factory objects" do 
    query = Graphlyte.query do |b|
      b.id
    end

    expect { query.something }.to raise_error do |e|
      expect(e.class).to be(NoMethodError)
    end
  end

  it "should convert snake_case to camelCase" do
    query = Graphlyte.query do |b|
      b.snake_case_works
      b.__type_name
      b.type_name__
      b.User # can't avoid this
    end
    expect(query.to_s).to eql(<<~STRING)
    {
      snakeCaseWorks
      __typeName
      typeName__
      User
    }
    STRING
  end

  it "should support buik queries" do 
    query_1 = Graphlyte.query do |b|
      b.bulk(id: 1) do |b|
        b.ok
      end
    end

    query_2 = Graphlyte.query do |b|
      b.bulk(id: 2) do |b|
        b.ok
      end
    end

    expect(query_1 + query_2).to eql(<<~STRING) 
    {
      bulk(id: 1) {
        ok
      }
    }
    
    {
      bulk(id: 2) {
        ok
      }
    }
    STRING
  end
end