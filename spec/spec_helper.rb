require "rspec"
require 'pry'
require "rest_client"
require "super_diff/rspec"

if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  require 'simplecov-html'
  require 'simplecov-cobertura'

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::CoberturaFormatter, SimpleCov::Formatter::HTMLFormatter])

  SimpleCov.start do
    add_filter '/tests/'
    add_filter '/spec/'
    add_filter '/fixture/'
  end
end

Dir["#{__dir__}/../lib/**/*.rb"].sort.each { |f| require f }
Dir["#{__dir__}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.project_source_dirs = ["#{__dir__}/../lib/"]
  config.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end

  config.include(Request, :requests)
  config.include(Fixtures, :fixtures)
  config.include(Mocks, :mocks)
end
