require "rspec"
require "rest_client"
require 'simplecov'
require 'simplecov-html'
require 'simplecov-cobertura'

require_relative "#{__dir__}/../lib/graphlyte"

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::CoberturaFormatter, SimpleCov::Formatter::HTMLFormatter])
SimpleCov.start do
  add_filter '/tests/'
end

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
