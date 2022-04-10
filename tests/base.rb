# frozen_string_literal: true
require 'rspec/expectations'
require 'rest_client'
require_relative "../lib/graphlyte"

module Tests
  module Request
    def request(json)
      host = ENV["HOST"] || "localhost"
      RestClient.post("http://#{host}:5000/raw", json, { 'Content-Type' => "application/json", 'Accept' => 'application/json' })
    end

    def tokenize(gql)
      ::Graphlyte::Schema::Lexer.new(gql).tokenize
    end

    def parse(gql)
      ::Graphlyte.parse(gql)
    end
  end

  class Base
    include Theorem::Hypothesis
    include RSpec::Matchers
    include Request

    before_each do
      @fixture = JSON.parse File.read("#{__dir__}/../fixture/mocks.json")
    end
  end
end
