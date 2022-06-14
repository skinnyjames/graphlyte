# frozen_string_literal: true

require 'json'

describe Graphlyte, :requests, :mocks do
  it 'should perform a basic query' do
    query = Graphlyte.query do |q|
      q.allTodos(&:id)
    end

    expected = mock_response('todo').map { |t| { 'id' => t['id'].to_s } }
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it 'should support fragments, argument syntax' do
    todo = Graphlyte.fragment('todoFields', on: 'Todo', &:title)

    query = Graphlyte.query do |q|
      q.allTodos(todo)
    end

    expected = mock_response('todo').map { |t| { 'title' => t['title'] } }
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it 'should support fragments, << syntax' do
    todo = Graphlyte.fragment('todoFields', on: 'Todo', &:title)

    query = Graphlyte.query do |q|
      q.allTodos { |todos| todos << todo }
    end

    expected = mock_response('todo').map { |t| { 'title' => t['title'] } }
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it 'should support nested fragments' do
    extra_fields = Graphlyte.fragment('extraFields', on: 'Todo') do |f|
      f.id
      f.status
    end

    todo = Graphlyte.fragment('todoFields', on: 'Todo') do |f|
      f.title
      f << extra_fields
    end

    query = Graphlyte.query do |q|
      q.allTodos todo
    end

    expected = mock_response('todo').map do |t|
      {
        'title' => t['title'],
        'id' => t['id'].to_s,
        'status' => t['status']
      }
    end
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it 'should support parsing fragments' do
    query = Graphlyte.parse(<<~GQL)
      query todos {
        allTodos {
          ...todoFields
         }
      }

      fragment extraFields on Todo {
        id
        status
      }

      fragment todoFields on Todo {
        title
        ...extraFields
      }
    GQL

    expected = mock_response('todo').map do |t|
      {
        'title' => t['title'],
        'id' => t['id'].to_s,
        'status' => t['status']
      }
    end
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it 'should support aliases and input' do
    query = Graphlyte.query do |q|
      q.User(id: 123, &:id).alias('sean')
      q.User(id: 456, &:id).alias('bob')
    end

    expected = { 'sean' => { 'id' => '123' }, 'bob' => { 'id' => '456' } }
    response = request(query)['data']

    expect(response).to eql(expected)
  end

  it 'should parse aliases and input' do
    query = Graphlyte.parse(<<~GQL)
      query users {
        sean: User(id: 123) {
          id
        }
        bob: User(id: 456) {
          id
        }
      }
    GQL
    expected = { 'sean' => { 'id' => '123' }, 'bob' => { 'id' => '456' } }
    response = request(query)['data']

    expect(response).to eql(expected)
  end

  it 'supports variables, inferring types appropriately' do
    query = Graphlyte.query do |q|
      q.all_todos(per_page: :per_page, page: :pages) do |t|
        t.status
        t.title
      end
    end

    expected = { 'allTodos' => [{ 'status' => 'open', 'title' => 'Sic Dolor amet' }] }

    response = request(query, per_page: 1, pages: 1)['data']

    expect(response).to eql(expected)
  end

  it 'supports scalar arguments' do
    sean_id = Graphlyte.var('ID!', 'sid') # TODO: allow this to be anonymous!
    todo_filter = Graphlyte.var('TodoFilter')

    fragment = Graphlyte.fragment('userFields', on: 'Query') do |q|
      q.User(id: sean_id, &:name)
    end

    query = Graphlyte.query do |q|
      q.all_todos(filter: todo_filter) do |t|
        t.status
        t.title
      end
      q << fragment
    end

    expected = { 'allTodos' => [{ 'status' => 'open', 'title' => 'Sic Dolor amet' }],
                 'User' => { 'name' => 'John Doe' } }

    response = request(query, sean_id.name => 123, todo_filter.name => { ids: [2] })

    expect(response['data']).to eql(expected)
  end

  it 'should support parsing scalars' do
    query = parse(<<~GQL)
      query todos($todoFilter: TodoFilter, $seanId: ID!) {
        allTodos(filter: $todoFilter) {
          status
          title
        }
        ...userFields
      }
      fragment userFields on Query {
        User(id: $seanId) {
          name
        }
      }
    GQL

    expected = {
      'allTodos' => [{ 'status' => 'open', 'title' => 'Sic Dolor amet' }],
      'User' => { 'name' => 'John Doe' }
    }

    response = request(query, todo_filter: { ids: [2] }, sean_id: 123)

    expect(response['data']).to eql(expected)
  end

  it 'should support argument variables' do
    query = Graphlyte.query do |q|
      q.User(id: Graphlyte.var('ID!', 'sean_id')).alias('sean') { _1.id }
      q.User(id: Graphlyte.var('ID!', 'bob_id')).alias('bob') { _1.id }
    end

    expected = { 'sean' => { 'id' => '123' }, 'bob' => { 'id' => '456' } }
    response = request(query, sean_id: 123, bob_id: 456)

    expect(response['data']).to eql(expected)
  end

  it 'should query for the schema' do
    response = request(Graphlyte.schema_query)['data']

    expect(response).not_to be(nil)
  end
end
