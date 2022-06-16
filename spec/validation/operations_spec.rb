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

    query.validate(schema)

    expect(query.validation_errors).to eql((<<~ERRORS * 2).chomp)
      Error on operationOne
      1.) ambiguous operation name operationOne

    ERRORS
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

    query.validate(schema)

    expect(query.validation_errors).to eql(<<~ERRORS)
      Error on document
      1.) cannot mix anonymous and named operations
    ERRORS
  end
end
