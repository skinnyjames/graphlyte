# frozen_string_literal: true

describe Graphlyte do
  it 'is possible to select fields that we cannot name in ruby' do
    query = Graphlyte.query do |q|
      q.hero do |q|
        q.select!(:select)
        q.select!(:open)
        q.select!(:if)
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
    query = Graphlyte.query do |q|
      q.hero do |h|
        h._
        h.on
        h.build
        h.argument_builder
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

  it 'supports aliases' do
    query = Graphlyte.query do |q|
      q.hero(name: 'Jo', &:name).alias(:jo)

      q.bill = q.hero(name: 'Bill', &:name)
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        jo: hero(name: "Jo") { name }
        bill: hero(name: "Bill") { name }
      }
    STRING
  end

  it 'supports directives' do
    query = Graphlyte.query do |q|
      q.hero(episode: :episode) do |hero|
        hero.name
        hero.friends.include(if: :with_friends) do |f|
          f.name
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

  it 'supports fragments, using <<' do
    fragment = Graphlyte.fragment(on: 'Friends', &:something)

    query = Graphlyte.query do |q|
      q.hero(episode: :episode) do |hero|
        hero << fragment
      end
    end

    expect(query).to produce_equivalent_document(<<~STRING)
      {
        hero(episode: $episode) {
          ... FriendsFields
        }
      }

      fragment FriendsFields on Friends {
        something
      }
    STRING
  end

  it 'supports inline fragments' do
    query = Graphlyte.query do |q|
      q.hero(episode: :episode) do |hero|
        hero.on!('Friends', &:something)
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

  it 'converts snake_case to camelCase' do
    query = Graphlyte.query do |q|
      q.snake_case_works
      q.__type_name
      q.type_name__
      q.User
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

  it 'should support bulk queries' do
    query1 = Graphlyte.query('FR') do |q|
      q.bulk(id: 1) do |b|
        b.bon
        b.mal
      end
    end

    query2 = Graphlyte.query('DE') do |q|
      q.bulk(id: 2) do |b|
        b.gut
        b.schlecht
      end
    end

    expect(query1 + query2).to produce_equivalent_document(<<~STRING)
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
end
