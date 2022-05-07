describe Graphlyte do 
  it 'is possible to select fields that we cannot name in ruby' do
    query = Graphlyte.query do
      hero do
        select!(:select)
        select!(:open)
        select!(:if)
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        hero {
          select open if
        }
      }
    STRING
  end

  it 'does not shadow fields' do
    query = Graphlyte.query do
      hero do
        _
        on
        build
        argument_builder
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        hero {
          _ on build argumentBuilder
        }
      }
    STRING
  end

  it 'should support directives' do
    query = Graphlyte.query do
      hero(episode: :episode) do
        name
        friends.include(if: :with_friends) do
          name
        end
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
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

  it 'supports inline fragments' do
    query = Graphlyte.query do
      hero(episode: :episode) do
        on!('Friends') do
          something
        end
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        hero(episode: $episode) {
          ... on Friends {
            something
          }
        }
      }
    STRING
  end

  it "converts snake_case to camelCase" do
    query = Graphlyte.query do
      snake_case_works
      __type_name
      type_name__
      self.User # must use self. to refer to 'constants'
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        snakeCaseWorks
        __typeName
        typeName__
        User
      }
    STRING
  end

  it "should support buik queries" do 
    query_1 = Graphlyte.query('FR') do
      bulk(id: 1) do |b|
        bon
        mal
      end
    end

    query_2 = Graphlyte.query('DE') do
      bulk(id: 2) do |b|
        gut
        schlecht
      end
    end

    expect(query_1 + query_2).to produce_equivalent_document(<<~STRING)
      query FR {
        bulk(id: 1) {
          bon mal
        }
      }

      query DE {
        bulk(id: 2) {
          gut schlecht
        }
      }
    STRING
  end

  context 'query scoping' do
    let(:fragment) do
      Graphlyte.fragment(on: 'User') { id }
    end

    it 'should provide an escape hatch to outer scope as a block parameter' do
      query = Graphlyte.query do |outer|
        user outer.fragment
      end

      expect(query).to produce_equivalent_document(<<~STRING)
        query { 
          user {
            ...UserFields
          }
        }

        fragment UserFields on User {
          id
        }
      STRING
    end
  end
end
