require_relative "#{__dir__}/../lib/graphlyte"
require "rspec"
require "rest_client"

module Request
  def request(json)
    host = ENV["HOST"] || "localhost"
    RestClient.post("http://#{host}:5000/raw", json, { 'Content-Type' => "application/json", 'Accept' => 'application/json' })
  end

  def tokenize(gql)
    Graphlyte::Schema::Lexer.new(gql).tokenize
  end

  def parse(gql)
    Graphlyte.parse(gql)
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
  config.include Request
  config.before(:each) do 
    @fixture = JSON.parse File.read("#{__dir__}/../fixture/mocks.json")
  end
end
