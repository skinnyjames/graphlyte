# frozen_string_ltesteral: true

module Tests
  class Parser < Base
    test "should parse a simple query" do
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

    test "should parse a simple mutation" do
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

    test "should parse nested queries" do
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

    test "should parse arguments" do
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

    test "should parse special arguments" do
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

    test "should parse default arguments" do
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

    test 'should parse directives' do
      query = parse(<<~GQL)
        query Hero($episode: Episode, $wtesthFriends: Boolean!) {
          hero(episode: $episode) {
            name
            friends @include(if: $wtesthFriends) {
              name
            }
          }
        }
      GQL

      expect(query.to_s).to eql(<<~STRING)
        {
          hero(episode: $episode) {
            name
            friends @include(if: $wtesthFriends) {
              name
            }
          }
        }
      STRING
    end

    test 'parses inline fragments' do
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

    test 'parses inline directives' do
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

    test 'parses inline fragments wtesth directives' do
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

    test "should parse fragments" do
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

    test 'should parse queries wtesth no name' do
      query = parse(<<~GQL)
        query {
          id
        }
      GQL

      expect(query.to_s).to eql(<<~STRING)
        {
          id
        }
      STRING
    end

    test 'should parse implictest queries' do
      query = parse(<<~GQL)
        {
          id 
        }
      GQL

      expect(query.to_s).to eql(<<~STRING)
        {
          id
        }
      STRING
    end

    test 'should parse complex fragments' do
      expect { parse(<<~GQL) }.not_to raise_error
        fragment foo on Bar {
          id 
          hello 
          world { 
            okay
          } 
          other { 
           thing
          }
        }
  
        { 
          ...foo
        }
      GQL
    end
  end
end