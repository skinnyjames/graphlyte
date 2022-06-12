# frozen_string_literal: true

RSpec.describe Graphlyte::Schema, :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'does not throw when fields are valid' do
    query = Graphlyte.query do |q|
      q.Todo(id: 123, &:id)
    end

    expect { query.validate(schema) }.not_to raise_error
  end

  it 'throws when required arguments are null' do
    query = Graphlyte.query do |q|
      q.User(id: nil, &:id).alias('sean')
    end

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('argument id on field User is required')
    end
  end

  it 'throws when required arguments are missing' do
    query = Graphlyte.query do |q|
      q.User(&:id).alias('sean')
    end

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('argument id on field User is required')
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

  it 'throws with duplicate argument names' do
    query = Graphlyte.parse <<~GQL
      query { 
        User(id: 123, id: 453) {
          id
        }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('ambiguous argument id on field User')
    end
  end
end