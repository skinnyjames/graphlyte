# frozen_string_literal: true

require 'rspec/expectations'
require 'super_diff/rspec'

RSpec::Matchers.define :produce_errors do |schema, error_arr|
  match do |doc|
    @actual = doc.validate(schema).validation_errors
    @expected = { errors: error_arr }
    expect(@actual).to eql(@expected)
  end

  def differ
    SuperDiff::RSpec::Differ
  end

  failure_message do
    "Errors not the same:\nDiff\n#{differ.new(@actual, @expected).diff}"
  end
end
