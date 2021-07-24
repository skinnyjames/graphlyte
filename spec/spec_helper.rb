require_relative "#{__dir__}/../lib/graphlyte"
require_relative "#{__dir__}/../lib/graphlyte/parsing/lexer"
require "rspec"


module Request
  def request(json)
    host = ENV["HOST"] || "localhost"
    RestClient.post("http://#{host}:5000", json, { 'Content-Type' => "application/json" })
  end
end

RSpec.configure do |config|
  config.include Request
  config.before(:each) do 
    @fixture = JSON.parse File.read("#{__dir__}/../fixture/mocks.json")
  end
end
