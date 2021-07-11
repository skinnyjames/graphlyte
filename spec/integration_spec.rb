require "rest_client"
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
end