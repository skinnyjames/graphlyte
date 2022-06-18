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

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        User
          id
            enum
      1.) value enum must be of ID - got ENUM
    ERROR
  end

  it 'validates complex value type' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { id: todo }) { id }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        allTodos
          filter
            id
              todo
      1.) value todo must be of ID - got ENUM
    ERROR
  end

  it 'validates a schema query' do
    query = Graphlyte.schema_query

    expect(query.validate(schema).validation_errors).to be(nil)
  end

  it 'validates array value' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { ids: [123, null] }) { id }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        allTodos
          filter
            ids
              null
      1.) value null must be of ID - got NULL
    ERROR
  end

  it 'validates an input object field names' do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { foo: bar }) { id }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        allTodos
          filter
      1.) Input object field foo does not exist on TodoFilter

      Error on something
        allTodos
          filter
            foo
              bar
      1.) value bar is invalid - no type
    ERROR
  end

  it 'validates required input object names', :focus do
    query = Graphlyte.parse <<~GQL
      mutation something {
        createManyUser(data: { })
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        createManyUser
          data
      1.) argument id is required
      2.) argument name is required
    ERROR
  end

  # todo: the following is not possible - last duplicate wins currently
  it 'validates duplicate input object field names', :focus do
    query = Graphlyte.query do |q|
      q.allTodos(filter: { id: 123, id: 456 }, &:id)
    end

    # todo: uncomment
    # expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
    #   Error on something
    #     allTodos
    #       filter
    #   1.) duplicate argument id
    # ERROR

    expect(query.validate(schema).validation_errors).to be(nil)
  end

end
