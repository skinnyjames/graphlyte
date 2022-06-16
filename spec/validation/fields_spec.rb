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
end
