# frozen_string_literal: true

RSpec.describe 'Value validation', :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'validates simple value type' do
    query = Graphlyte.parse <<~GQL
      query something {
        User(id: enum) {
          id
        }
      }
    GQL

    errors = [{ message: 'value enum must be of ID - got ENUM', path: %w[something User id enum] }]
    expect(query).to produce_errors(schema, errors)
  end

  it 'validates complex value type' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { id: todo }) { id }
      }
    GQL

    errors = [{ message: 'value todo must be of ID - got ENUM', path: %w[something allTodos filter id todo] }]
    expect(query).to produce_errors(schema, errors)
  end

  it 'validates a schema query' do
    query = Graphlyte.schema_query

    expect(query).to produce_errors(schema, [])
  end

  it 'validates array value' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { ids: [123, null] }) { id }
      }
    GQL

    errors = [{ message: 'value null must be of ID - got NULL', path: %w[something allTodos filter ids null] }]
    expect(query).to produce_errors(schema, errors)
  end

  it 'validates an input object field names' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { foo: bar }) { id }
      }
    GQL

    errors = [
      { message: 'Input object field foo does not exist on TodoFilter', path: %w[something allTodos filter] },
      { message: 'value bar is invalid - no type', path: %w[something allTodos filter foo bar] }
    ]
    expect(query).to produce_errors(schema, errors)
  end

  it 'validates required input object names' do
    query = Graphlyte.parse <<~GQL
      mutation something {
        createManyUser(data: { })
      }
    GQL

    errors = [
      { message: 'argument id is required', path: %w[something createManyUser data] },
      { message: 'argument name is required', path: %w[something createManyUser data] }
    ]
    expect(query).to produce_errors(schema, errors)
  end

  # todo: the following is not possible - last duplicate wins currently
  it 'validates duplicate input object field names' do
    query = Graphlyte.query do |q|
      q.allTodos(filter: { id: 123, id: 456 }, &:id)
    end

    expect(query).to produce_errors(schema, [])
  end
end
