# frozen_string_literal: true

RSpec.describe Graphlyte::Schema, :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws when field subselection is empty' do
    query = Graphlyte.query do |q|
      q.User(id: nil)
    end

    query.validate(schema).validation_errors
  end

  it 'does not throw when fields are valid', :focus do
    query = Graphlyte.parse <<~GQL
      query { 
        User(id: null) { 
          Todos {
            ... on String { id }
          }
        }
      }
    GQL

    puts query.validate(schema).validation_errors

    query
  end

  it 'annotates circular fragments', :focus do
    query = Graphlyte.parse <<~GQL
      query { 
        User(id: 123) {
          ...fragmentOne
        }  
      }

      fragment fragmentOne on User {
        ...fragmentTwo
      }

      fragment fragmentTwo on User {
        ...fragmentThree
      }

      fragment fragmentThree on User {
        ...fragmentOne
      }
    GQL

    puts query.validate(schema).validation_errors
  end
end