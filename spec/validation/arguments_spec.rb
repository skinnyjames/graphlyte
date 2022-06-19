# frozen_string_literal: true

RSpec.describe 'Argument validation', :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws when required arguments are null' do
    query = Graphlyte.query('something') do |q|
      q.User(id: nil, &:id).alias('sean')
    end

    errors = [
      { message: 'argument id on field User is required', path: %w[something User] },
      { message: 'value null must be of ID - got NULL', path: %w[something User id null] }
    ]

    expect(query).to produce_errors(schema, errors)
  end

  it 'throws when required arguments are missing' do
    query = Graphlyte.query('something') do |q|
      q.User(&:id).alias('sean')
    end

    errors = [{ message: 'argument id on field User is required', path: %w[something User] }]

    expect(query).to produce_errors(schema, errors)
  end

  it 'throws with duplicate argument names' do
    query = Graphlyte.parse <<~GQL
      query query {
        User(id: 123, id: 453) {
          id
        }
      }
    GQL

    errors = [{ message: 'has ambiguous args: id', path: %w[query User] }]
    expect(query).to produce_errors(schema, errors)
  end

  it 'ensures argument name definitions' do
    query = Graphlyte.parse <<~GQL
      query query { 
        allTodos(foo: {}) { id }
      }
    GQL

    errors = [{ message: 'Argument foo not defined on allTodos', path: %w[query allTodos foo] }]
    expect(query).to produce_errors(schema, errors)
  end
end
