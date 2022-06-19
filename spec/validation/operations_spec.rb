# frozen_string_literal: true

RSpec.describe 'Operation validation', :requests, :mocks do
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

    errors = [{ message: 'ambiguous operation name operationOne', path: %w[operationOne] }]
    expect(query).to produce_errors(schema, errors)
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

    errors = [{ message: 'cannot mix anonymous and named operations', path: %w[document] }]
    expect(query).to produce_errors(schema, errors)
  end
end
