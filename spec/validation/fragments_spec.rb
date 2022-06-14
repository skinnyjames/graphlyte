# frozen_string_literal: true

RSpec.describe Graphlyte::Validation, :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws with duplicate fragment names' do
    query = Graphlyte.parse <<~GQL
      query {
        ...fragmentOne
      }

      fragment fragmentOne on User {
        id
      }

      fragment fragmentOne on Todo {
        id
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('ambiguous fragment name fragmentOne')
    end
  end

  it 'throws if fragment spread targets are not defined', :focus do
    query = Graphlyte.parse <<~GQL
      query {
        ...fragmentOne
      }

      fragment fragmentOne on Foobar {
        id
        ...fragmentTwo
      }

      fragment fragmentTwo on Todo {
        ... on Foobar {
          fun
        }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragmentOne target Foobar not found', 'inline target Foobar not found')
      end
    end
  end

  it 'throws if fragment type is a scalar' do
    query = Graphlyte.parse <<~GQL
      query {
        ...fragmentOne
      }

      fragment fragmentOne on String {
        id
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragmentOne target String must be kind of UNION, INTERFACE, or OBJECT')
      end
    end
  end

  it 'throws on unused fragments' do
    query = Graphlyte.parse <<~GQL
      query {
        allTodos {
          id
        }
      }

      fragment one on Todo {
        id
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragment one on Todo must be used in document')
      end
    end
  end

  it 'throws on circular fragment spreads' do
    query = Graphlyte.parse <<~GQL
      query {
        ...fragmentOne
      }

      fragment fragmentOne on Todo {
        ...fragmentTwo
      }

      fragment fragmentTwo on Todo {
        ...fragmentThree
      }

      fragment fragmentThree on Todo {
         ...fragmentOne
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('fragment spread fragmentOne cannot be circular')
    end
  end
end
