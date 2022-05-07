require "json"

describe Graphlyte, :requests, :mocks do
  it "should perform a basic query" do
    query = Graphlyte.query do
      allTodos do
        id
      end
    end

    expected = mock_response("todo").map { |t| { "id" => t['id'].to_s } }
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it "should support fragments" do 
    todo = Graphlyte.fragment("todoFields", on: "Todo") do
      title
    end

    query = Graphlyte.query do
      allTodos todo
    end

    expected = mock_response("todo").map {|t| { "title" => t["title"] } }
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it "should support nested fragments" do 
    extra_fields = Graphlyte.fragment('extraFields', on: "Todo") do
      id
      status
    end

    todo = Graphlyte.fragment('todoFields', on: "Todo") do
      title
      self << extra_fields
    end

    query = Graphlyte.query do |q|
      allTodos todo
    end

    expected = mock_response("todo").map do |t|
      { 
        "title" => t["title"],
        "id" => t["id"].to_s,
        "status" => t["status"]
      }
    end
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it "should support parsing fragments" do
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

    expected = mock_response("todo").map do |t|
      {
        "title" => t["title"],
        "id" => t["id"].to_s,
        "status" => t["status"]
      }
    end
    response = request(query).dig('data', 'allTodos')

    expect(response).to eql(expected)
  end

  it "should support aliases and input" do 
    query = Graphlyte.query do
      self.User(id: 123).alias("sean") do
        id
      end
      self.User(id: 456).alias("bob") do
        id
      end
    end

    expected = { "sean" => { "id" => "123"}, "bob" => {"id" => "456" } }
    response = request(query)["data"]

    expect(response).to eql(expected)
  end

  it "should parse aliases and input" do
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
    expected = { "sean" => { "id" => "123"}, "bob" => {"id" => "456" } }
    response = request(query)["data"]

    expect(response).to eql(expected)
  end

  it "supports variables, inferring types appropriately" do 
    query = Graphlyte.query do 
      all_todos(per_page: :per_page, page: :pages) do
        status
        title
      end
    end

    expected = {"allTodos" => [{"status" => "open", "title" => "Sic Dolor amet"}]}

    response = request(query, per_page: 1, pages: 1)["data"]

    expect(response).to eql(expected)
  end

  it "supports scalar arguments" do
    sean_id = Graphlyte.var('ID!', 'sid') # TODO: allow this to be anonymous!
    todo_filter = Graphlyte.var('TodoFilter')

    fragment = Graphlyte.fragment("userFields", on: "Query") do
      User(id: sean_id) do
        name
      end
    end

    query = Graphlyte.query do
      all_todos(filter: todo_filter) do
        status
        title
      end
      self << fragment
    end

    expected = {"allTodos"=>[{"status"=>"open", "title"=>"Sic Dolor amet"}], "User"=>{"name"=>"John Doe"}}

    response = request(query, sean_id.name => 123, todo_filter.name => { ids: [2] })

    expect(response['data']).to eql(expected)
  end

  it "should support parsing scalars", :focus do
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
      "allTodos"=>[{"status"=>"open", "title"=>"Sic Dolor amet"}],
      "User"=>{"name"=>"John Doe"}
    }

    response = request(query, todo_filter: {ids: [2]}, sean_id: 123)

    expect(response['data']).to eql(expected)
  end

  it "should support argument variables" do 
    query = Graphlyte.query do
      User(id: Graphlyte.var('ID!', 'sean_id')).alias("sean") { id }
      User(id: Graphlyte.var('ID!', 'bob_id')).alias("bob") { id }
    end

    expected = { "sean" => { "id" => "123"}, "bob" => {"id" => "456" } }
    response = request(query, sean_id: 123, bob_id: 456)

    expect(response['data']).to eql(expected)
  end

  it "should query for the schema" do 
    response = request(Graphlyte.schema_query)['data']

    expect(response).not_to be(nil)
  end
end
