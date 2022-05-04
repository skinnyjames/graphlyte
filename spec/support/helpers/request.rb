# frozen_string_literal: true

module Request
  def request(document, **variables)
    host = ENV["HOST"] || "localhost"
    json = document.request_body(**variables)
    RestClient.post("http://#{host}:5000/raw", json, { 'Content-Type' => "application/json", 'Accept' => 'application/json' })
  end

  def parse(gql)
    Graphlyte.parse(gql)
  end
end
