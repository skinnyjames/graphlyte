describe Graphlyte::Schema::Parser, :parser do
  it "should parse a simple query" do
    query = parse(<<~GQL)
      query hello {
        world
      }
    GQL
    expect(query.class).to be(Graphlyte::Query)
    expect(query.to_s).to eql(<<~STR)
      {
        world
      }
    STR
  end

  it "should parse a simple mutation" do
    mutation = parse(<<~GQL)
      mutation hello {
        world  
      }
    GQL
    expect(mutation.class).to be(Graphlyte::Query)
    expect(mutation.to_s).to eql(<<~STR)
      {
        world
      }
    STR
  end

  it "should parse nested queries" do
    query = parse(<<~GQL)
      query hello {
        nested {
          world
        }
        world
      }
    GQL
    expect(query.to_s).to eql(<<~STR)
      {
        nested {
          world
        }
        world
      }
    STR
  end

  it "should parse arguments" do
    query = parse(<<~GQL)
      query hello {
        nested(int: 1, string: "hello", float: 1.0, bool: true, arr: [1,2,3], hash: { nested: { hash: "string"}}) {
          world
        }
      }
    GQL

    expect(query.to_s).to eql(<<~STR)
      {
        nested(int: 1, string: "hello", float: 1.0, bool: true, arr: [1, 2, 3], hash: { nested: { hash: "string" } }) {
          world
        }
      }
    STR
  end

  it "should parse special arguments" do
    query = parse(<<~GQL)
      query hello($id: !Int) {
        nested(id: $id) {
          world
        }
      }
    GQL

    expect(query.placeholders).to include(":id of !Int")
    expect(query.to_s).to eql(<<~STR)
      {
        nested(id: $id) {
          world
        }
      }
    STR
  end

  it "should parse default arguments" do
    query = parse(<<~GQL)
      query hello($id: [!Int] = [1,2,3]) {
        nested(id: $id) {
          world
        }
      }
    GQL

    expect(query.placeholders).to include(":id of [!Int] with default [1, 2, 3]")
    expect(query.to_s).to eql(<<~STR)
      {
        nested(id: $id) {
          world
        }
      }
    STR
  end

  it 'should parse directives' do
    query = parse(<<~GQL)
      query Hero($episode: Episode, $withFriends: Boolean!) {
        hero(episode: $episode) {
          name
          friends @include(if: $withFriends) {
            name
          }
        }
      }
    GQL

    expect(query.to_s).to eql(<<~STRING)
      {
        hero(episode: $episode) {
          name
          friends @include(if: $withFriends) {
            name
          }
        }
      }
    STRING
  end

  it 'parses inline fragments' do
    query = Graphlyte.parse <<~GQL
      query inlineFragmentNoType($expandedInfo: Boolean) {
        user(handle: "zuck") {
          id
          name
          ... on Something {
            firstName
            lastName
            birthday
          }
        }
      }
    GQL

    expect(query.to_s).to eql(<<~STRING)
      {
        user(handle: "zuck") {
          id
          name
          ... on Something {
            firstName
            lastName
            birthday
          }
        }
      }
    STRING
  end

  it 'parses inline directives' do
    query = Graphlyte.parse <<~GQL
      query inlineFragmentNoType($expandedInfo: Boolean) {
        user(handle: "zuck") {
          id
          name
          ... @include(if: $expandedInfo) {
            firstName
            lastName
            birthday
          }
        }
      }
    GQL

    expect(query.to_s).to eql(<<~STRING)
      {
        user(handle: "zuck") {
          id
          name
          ... @include(if: $expandedInfo) {
            firstName
            lastName
            birthday
          }
        }
      }
    STRING
  end

  it 'parses inline fragments with directives' do
    query = Graphlyte.parse <<~GQL
      query inlineFragmentNoType($expandedInfo: Boolean) {
        user(handle: "zuck") {
          id
          name
          ... on Something @include(if: $expandedInfo) {
            firstName
            lastName
            birthday
          }
        }
      }
    GQL

    expect(query.to_s).to eql(<<~STRING)
      {
        user(handle: "zuck") {
          id
          name
          ... on Something @include(if: $expandedInfo) {
            firstName
            lastName
            birthday
          }
        }
      }
    STRING
  end

  it "should parse fragments" do
    query = parse(<<~GQL)
      query hello {
        ...outerFragment
        nested {
          ...nestedFragment
        }
      }

      fragment nestedFragment on Idea {
        world
      }

      fragment outerFragment on Idea {
        outer {
          ...internalFragment
        }    
      }

      fragment internalFragment on Idea {
        thing
      }
    GQL

    expect(query.to_s).to eql(<<~STR.strip!)
      {
        ...outerFragment  
        nested {
          ...nestedFragment    
        }
      }
    
      fragment outerFragment on Idea {
        outer {
          ...internalFragment    
        }
      }
      fragment internalFragment on Idea {
        thing
      }
      fragment nestedFragment on Idea {
        world
      }
    STR
  end
end