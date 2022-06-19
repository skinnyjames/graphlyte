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

    query.validate(schema)
    expect(query.validation_errors).to eql(<<~ERRORS)
      Error on something
        User
      1.) argument id on field User is required

      Error on something
        User
          id
            null
      1.) value null must be of ID - got NULL
    ERRORS
  end

  it 'throws when required arguments are missing' do
    query = Graphlyte.query('something') do |q|
      q.User(&:id).alias('sean')
    end

    query.validate(schema)
    expect(query.validation_errors).to eql(<<~ERRORS)
      Error on something
        User
      1.) argument id on field User is required
    ERRORS
  end

  it 'throws with duplicate argument names' do
    query = Graphlyte.parse <<~GQL
      query query {
        User(id: 123, id: 453) {
          id
        }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on query
        User
      1.) has ambiguous args: id
    ERRORS
  end

  it 'ensures argument name definitions' do
    query = Graphlyte.parse <<~GQL
      query query { 
        allTodos(foo: {}) { id }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on query
        allTodos
          foo
      1.) Argument foo not defined on allTodos
    ERRORS
  end
end
