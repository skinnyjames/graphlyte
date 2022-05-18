# frozen_string_literal: true

module Fixtures
  def fixture(name)
    File.read("spec/graphql/#{name}.graphql")
  end
end
