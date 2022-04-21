# frozen_string_literal: true

module Request
  def request(document, variables = nil)
    host = ENV["HOST"] || "localhost"
    json = {
      query: Graphlyte::Serializer.dump(document),
      variables: variables
    }.to_json
    RestClient.post("http://#{host}:5000/raw", json, { 'Content-Type' => "application/json", 'Accept' => 'application/json' })
  end

  def parse(gql)
    Graphlyte.parse(gql)
  end
end
