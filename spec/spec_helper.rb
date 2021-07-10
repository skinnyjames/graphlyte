require_relative "#{__dir__}/../lib/graphlyte"
require "rspec"

host = ENV["HOST"] || "localhost"

module Request
  def request(json)
    RestClient.post("http://#{host}:5000", json, { 'Content-Type' => "application/json" })
  end
end

RSpec.configure do |config|
  config.include Request
  config.before(:each) do 
    @fixture = JSON.parse File.read("#{__dir__}/../fixture/mocks.json")
  end
end
