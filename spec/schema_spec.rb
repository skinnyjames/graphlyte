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
end
