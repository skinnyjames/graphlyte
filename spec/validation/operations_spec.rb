# frozen_string_literal: true

RSpec.describe Graphlyte::Validation, :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
    end
  end

  it 'throws on duplicate operations' do
    query = Graphlyte.parse <<~GQL
      query operationOne {
        allTodos {
          id
        }
      }

      query operationOne {
        allTodos {
          id
        }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('ambiguous operation name operationOne')
    end
  end

  it 'throws on mixing named and anonymous operations' do
    query = Graphlyte.parse <<~GQL
      {
        allTodos { id }
      }

      query operationTwo {
        allTodos { id }
      }
    GQL

    expect { query.validate(schema) }.to raise_error do |err|
      expect(err.messages).to include('cannot mix anonymous and named operations')
    end
  end
end