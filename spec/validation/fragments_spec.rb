# frozen_string_literal: true

RSpec.describe 'Fragment validation', :requests, :mocks do
  let(:schema) do
    Graphlyte.load_schema do |query|
      request(query)
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

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on fragmentOne
      1.) ambiguous name fragmentOne

      Error on fragmentOne
      1.) ambiguous name fragmentOne
    ERRORS
  end

  it 'throws if fragment spread targets are not defined' do
    query = Graphlyte.parse <<~GQL
      query something {
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

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on something
        fragmentOne
      1.) target Foobar not found
      2.) target Foobar must be kind of UNION, INTERFACE, or OBJECT

      Error on fragmentTwo
        Foobar
      1.) inline target Foobar not found
      2.) inline target Foobar must be kind of UNION, INTERFACE, or OBJECT
    ERRORS
  end

  it 'throws if fragment type is a scalar' do
    query = Graphlyte.parse <<~GQL
      query query {
        ...fragmentOne
      }

      fragment fragmentOne on String {
        id
      }
    GQL

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on query
        fragmentOne
      1.) target String must be kind of UNION, INTERFACE, or OBJECT
    ERRORS
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

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on one
      1.) fragment must be used
    ERRORS
  end

  it 'throws on circular fragment spreads' do
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

    expect(query.validate(schema).validation_errors).to eql(<<~ERRORS)
      Error on fragmentOne
      1.) Circular reference: fragmentOne > fragmentTwo > fragmentThree > fragmentOne

      Error on fragmentTwo
      1.) Circular reference: fragmentTwo > fragmentThree > fragmentOne > fragmentTwo

      Error on fragmentThree
      1.) Circular reference: fragmentThree > fragmentOne > fragmentTwo > fragmentThree
    ERRORS
  end
end
