# frozen_string_literal: true

RSpec.describe 'Field validation', :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws when required selection is empty' do
    query = Graphlyte.query('something') do |q|
      q.User(id: 123)
    end

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        User
      1.) selection on field User can't be empty
    ERROR
  end

  it 'annotates invalid types on fields' do
    query = Graphlyte.parse <<~GQL
      query something {
        User(id: 123) {
          foobar
        }
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on something
        User
          foobar
      1.) field foobar is not defined on User
    ERROR
  end

  it 'no errors for correct fields on lists' do
    query = Graphlyte.parse <<~GQL
      query something {
        User(id: 123) {
          ...fragmentOne
        }
      }
      fragment fragmentOne on User {
        Todos {
          id
        }
      }
    GQL

    expect(query.validate(schema).validation_errors).to be(nil)
  end

  it 'annotates invalid types on fragments' do
    query = Graphlyte.parse <<~GQL
      query something {
        User(id: 123) {
          Todos {
            ...fragmentOne
          }
        }
      }

      fragment fragmentOne on Todo {
        id
        foobar
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERROR)
      Error on fragmentOne
        foobar
      1.) field foobar is not defined on Todo
    ERROR
  end
end
