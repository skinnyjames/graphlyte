# frozen_string_literal: true

require 'json'
require 'rest-client'

module Request
  def request(document, **variables)
    host = ENV['HOST'] || 'localhost'
    json = document.request_body(**variables)
    JSON.parse(RestClient.post("http://#{host}:5000/raw", json,
                               { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }))
  end

  def parse(gql)
    Graphlyte.parse(gql)
  end

  def request_schema(uri, headers = {})
    body = { query: schema_query.to_s }.to_json
    headers = { content_type: :json, accept: :json }.merge(headers)

    resp = RestClient.post(uri, body, headers)

    Schema.from_schema_response(JSON.parse(resp.body))
  end
end
