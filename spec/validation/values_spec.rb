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

  it 'validates complex value type', :focus do
    query = Graphlyte.parse <<~GQL
      query something {
        allTodos(filter: { id: 123 }) { id }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        allTodos(filter: { id: 123 }) { id }

    ERROR
  end

  it 'validates a schema query' do
    query = Graphlyte.schema_query

    expect(query.validate(schema).validation_errors).to be(nil)
  end
end