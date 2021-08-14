require "json"
describe Graphlyte do 
  it "should perform a basic query" do 
    query = Graphlyte.query do |q|
      q.allTodos do |t|
        t.id
      end
    end
    expected = @fixture["todo"].map {|t| { "id" => t['id'].to_s } }
    response = JSON.parse(request(query.to_json))["data"]
    expect(expected).to eql(response['allTodos'])
  end

  it "should support fragments" do 
    todo = Graphlyte.fragment("todoFields", "Todo") do |f|
      f.title
    end

    query = Graphlyte.query do |q|
      q.allTodos todo
    end

    expected = @fixture["todo"].map {|t| { "title" => t["title"] } }
    response = JSON.parse(request(query.to_json))["data"]
    expect(response["allTodos"]).to eql(expected) 
  end

  it "should support nested fragments" do 
    extra_fields = Graphlyte.fragment('extraFields', "Todo") do |f|
      f.id
      f.status
    end

    todo = Graphlyte.fragment('todoFields', "Todo") do |f|
      f.title
      f << extra_fields
    end

    query = Graphlyte.query do |q|
      q.allTodos todo
    end

    expected = @fixture["todo"].map do |t|
      { 
        "title" => t["title"],
        "id" => t["id"].to_s,
        "status" => t["status"]
      }
    end
    response = JSON.parse(request(query.to_json))["data"]
    expect(response["allTodos"]).to eql(expected) 
  end

  it "should support aliases and input" do 
    query = Graphlyte.query do
      User(id: 123).alias("sean") do
        id
      end
      User(id: 456).alias("bob") do
        id
      end
    end

    expected = { "sean" => { "id" => "123"}, "bob" => {"id" => "456" } }
    response = JSON.parse(request(query.to_json))["data"]
    expect(response).to eql(expected)
  end

  it "should support primitive variables" do 
    query = Graphlyte.query do 
      all_todos(per_page: :per_page, page: :pages) do
        status
        title 
      end
    end
    json = query.to_json(per_page: 1, pages: 1)
    expected = {"allTodos" => [{"status" => "open", "title" => "Sic Dolor amet"}]}
    begin
      response = JSON.parse(request(json))["data"]
    rescue RestClient::ExceptionWithResponse => e
      puts e.response.body
    end
    expect(response).to eql(expected)
  end

  it "should support scalar arguments" do
    fragment = Graphlyte.fragment("userFields", "Query") do 
      User(id: Graphlyte::TYPES.ID!(:sean_id)) do
        name         
      end
    end
    
    query = Graphlyte.query do |f|
      all_todos(filter: Graphlyte::TYPES.TodoFilter(:todo_filter)) do
        status
        title
      end
      f << fragment
    end

    json = query.to_json(todo_filter: {ids: [2]}, sean_id: 123)
    begin
      response = JSON.parse(request(json))["data"]
    rescue RestClient::ExceptionWithResponse => e
      puts e.response.body
    end
  end

  it "should support argument variables" do 
    query = Graphlyte.query do 
      User(id: Graphlyte::TYPES.ID!(:sean_id)).alias("sean") { id }
      User(id: Graphlyte::TYPES.ID!(:bob_id)).alias("bob") { id }
    end
    expected = { "sean" => { "id" => "123"}, "bob" => {"id" => "456" } }
    json = query.to_json(sean_id: 123, bob_id: 456)
    begin
      response = JSON.parse(request(json))["data"]
    rescue RestClient::ExceptionWithResponse => e
      puts e.response.body
    end
    expect(response).to eql(expected)
  end

  it "should query for the schema" do 
    query = Graphlyte.schema_query.to_json
    response = JSON.parse(request(query))['data']
    expect(response).not_to be(nil)
  end
end