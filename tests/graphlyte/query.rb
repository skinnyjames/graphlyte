# frozen_string_literal: true

module Tests
  class Query < Base
    test 'does not expose method_missing on factory objects' do
      query = Graphlyte.query do |b|
        b.id
      end

      expect { query.something }.to raise_error do |e|
        expect(e.class).to be(NoMethodError)
      end
    end

    test 'supports directives' do
      query = Graphlyte.query do
        hero(episode: Graphlyte::TYPES.episode(:episode)) do
          name
          friends.include(if: Graphlyte::TYPES.withFriends(:with_friends)) do
            name
          end
        end
      end

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

    test 'supports inline fragments' do
      query = Graphlyte.query do
        hero(episode: Graphlyte::TYPES.episode(:episode)) do |f|
          f << Graphlyte.inline_fragment('Friends') do
            something
          end
        end
      end

      expect(query.to_s).to eql(<<~STRING)
        {
          hero(episode: $episode) {
            ... on Friends {
              something
            }
          }
        }
      STRING
    end


    test 'supports inline directives' do
      directive = Graphlyte::Directive.new(:include, if: Graphlyte::TYPES.expandedInfo(:expanded_info))

      query = Graphlyte.query do
        hero(episode: Graphlyte::TYPES.episode(:episode)) do |f|
          f << Graphlyte.inline_directive(directive) do
            first_name
            last_name
            birthday
          end
        end
      end

      expect(query.to_s).to eql(<<~STRING)
        {
          hero(episode: $episode) {
            ... @include(if: $expandedInfo) {
              firstName
              lastName
              birthday
            }
          }
        }
      STRING

      expect(query.placeholders).to eql(<<~STRING.chomp)
        :episode of episode
        :expanded_info of expandedInfo
      STRING
    end

    test 'converts snake_case to camelCase' do
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

    test 'supports bulk queries' do
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
end