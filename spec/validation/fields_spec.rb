# frozen_string_literal: true

RSpec.describe Graphlyte::Editors::Validation, :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws when required selection is empty' do
    query = Graphlyte.query do |q|
      q.User(id: 123)
    end

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('selection on field User can\'t be empty')
    end
  end

  it 'throws when field is not defined on type' do
    query = Graphlyte.parse <<~GQL
      query {
        User(id: 123) {
          HowdyHo
          Todos {
            id
            foobar
          }
        }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('HowdyHo is not defined on User', 'foobar is not defined on Todos')
    end
  end

  it 'throws when field is not defined on type (fragments)' do
    query = Graphlyte.parse <<~GQL
      query {
        User(id: 123) {
          HowdyHo
          Todos { ...hello }
        }
      }

      fragment hello on Todo {
        id
        foobar
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('HowdyHo is not defined on User', 'foobar is not defined on Todo')
    end
  end
end