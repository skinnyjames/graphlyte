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

    errors = [{ message: 'selection on field User can\'t be empty', path: %w[something User]}]
    expect(query).to produce_errors(schema, errors)
  end

  it 'annotates invalid types on fields' do
    query = Graphlyte.parse <<~GQL
      query something {
        User(id: 123) {
          foobar
        }
      }
    GQL

    errors = [{ message: 'field foobar is not defined on User', path: %w[something User foobar]}]
    expect(query).to produce_errors(schema, errors)
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

    expect(query).to produce_errors(schema, [])
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

    errors = [{ message: 'field foobar is not defined on Todo', path: %w[fragmentOne foobar] }]
    expect(query).to produce_errors(schema, errors)
  end
end
