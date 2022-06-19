# frozen_string_literal: true

RSpec.describe 'Fragment validation', :requests, :mocks, :focus do
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

    errors = [{ message: 'ambiguous name fragmentOne', path: %w[fragmentOne] }]
    expect(query).to produce_errors(schema, errors)
  end

  it 'throws if fragment spread targets are not defined' do
    query = Graphlyte.parse <<~GQL
      query something {
        ...fragmentOne
      }

      fragment fragmentOne on Foobar {
        ...fragmentTwo
      }

      fragment fragmentTwo on Todo {
        id
        ... on Foobar { id }
      }
    GQL

    errors = [
      { message: 'target Foobar not found', path: %w[something fragmentOne] },
      { message: 'Foobar is not defined on Query', path: %w[something fragmentOne] },
      { message: 'target Foobar must be kind of UNION, INTERFACE, or OBJECT', path: %w[something fragmentOne] },
      { message: 'Todo target Foobar does not exist', path: %w[fragmentOne fragmentTwo] },
      { message: 'Foobar is not defined on Todo', path: %w[fragmentTwo Foobar] },
      { message: 'inline target Foobar not found', path: %w[fragmentTwo Foobar] },
      { message: 'inline target Foobar must be kind of UNION, INTERFACE, or OBJECT', path: %w[fragmentTwo Foobar] },
      { message: 'field id is not defined on Foobar', path: %w[fragmentTwo Foobar id]}
    ]

    expect(query).to produce_errors(schema, errors)
  end

  it 'throws if fragment type is a scalar' do
    query = Graphlyte.parse <<~GQL
      query query {
        ...fragmentOne
      }

      fragment fragmentOne on String {
        id
      }
    GQL

    errors = [
      { message: 'String is not defined on Query', path: %w[query fragmentOne] },
      { message: 'target String must be kind of UNION, INTERFACE, or OBJECT', path: %w[query fragmentOne] },
      { message: 'field id is not defined on String', path: %w[fragmentOne id] }
    ]

    expect(query).to produce_errors(schema, errors)
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

    errors = [{ message: 'fragment must be used', path: %w[one] }]
    expect(query).to produce_errors(schema, errors)
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

    errors = [
      { message: 'Circular reference: fragmentOne > fragmentTwo > fragmentThree > fragmentOne', path: %w[fragmentOne] },
      { message: 'Circular reference: fragmentTwo > fragmentThree > fragmentOne > fragmentTwo', path: %w[fragmentTwo] },
      { message: 'Circular reference: fragmentThree > fragmentOne > fragmentTwo > fragmentThree', path: %w[fragmentThree] }
    ]

    expect(query).to produce_errors(schema, errors)
  end

  context 'Fragment spread is possible' do
    it 'object spreads in object scope' do
      query = Graphlyte.parse <<~GQL
        query query { 
          ...fragmentOne
        }
      
        fragment fragmentOne on Todo {
          ... on Done { status  }
        }
      GQL

      errors = [
        { message: 'Done is not defined on Todo', path: %w[fragmentOne Done] },
        { message: 'field status is not defined on Done', path: %w[fragmentOne Done status] } # or is it?
      ]

      expect(query).to produce_errors(schema, errors)
    end

    it 'spread object spreads in object scope' do
      query = Graphlyte.parse <<~GQL
        query query {
          ...fragmentOne
        }
      
        fragment fragmentOne on Todo {
          ...fragmentTwo
        }

        fragment fragmentTwo on Done { id }
      GQL

      errors = [{ message: 'Done is not defined on Todo', path: %w[fragmentOne fragmentTwo] }]
      expect(query).to produce_errors(schema, errors)
    end
  end
end
