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

  it 'throws with duplicate fragment names' do
    query = Graphlyte.parse <<~GQL
      query { 
        ...fragmentOne
      }

      fragment fragmentOne on User {
        id
      }

      fragment fragmentOne on Todo {
        id
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.message).to include('ambiguous fragment name fragmentOne')
    end
  end

  it 'throws if fragment spread targets are not defined' do
    query = Graphlyte.parse <<~GQL
      query { 
        ...fragmentOne
      }

      fragment fragmentOne on Foobar {
        id
        ...fragmentTwo 
      }

      fragment fragmentTwo on Todo {
        ... on Foobar {
          fun
        }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragmentOne target Foobar not found', 'inline target Foobar not found')
      end
    end
  end

  it 'throws if fragment type is a scalar' do
    query = Graphlyte.parse <<~GQL
      query {
        ...fragmentOne
      }
      
      fragment fragmentOne on String {
        id  
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragmentOne target String must be kind of UNION, INTERFACE, or OBJECT')
      end
    end
  end

  it 'throws on unused fragments' do
    query = Graphlyte.parse <<~GQL
      query { 
        allTodos { 
          id
        }
      }

      fragment one on Todo {
        id
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      aggregate_failures do
        expect(err.messages).to include('fragment one on Todo must be used in document')
      end
    end
  end

  it 'throws on cyclomatic fragment spreads' do
    query = Graphlyte.parse <<~GQL
      query { 
        ...fragmentOne
      }

      fragment fragmentOne on Todo {
        ...fragmentTwo
      }

      fragment fragmentTwo on Todo {
        ...fragmentThree
      }

      fragment fragmentThree on Todo { 
         ...fragmentOne
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('fragment spread fragmentOne cannot be circular')
    end
  end
end