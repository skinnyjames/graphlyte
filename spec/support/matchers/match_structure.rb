# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_structure do |structure|
  match do |actual|
    @structure = process_structure(structure)

    raise 'structure must be a hash' unless structure.is_a?(Hash)

    @failed_keys = []

    structure.each do |key, expectation|
      value = subvalue(key, actual)

      next if values_match?(expectation, value)

      @failed_keys << key
    rescue KeyError
      @failed_keys << key
    end

    @failed_keys.empty?
  end

  failure_message do |actual|
    lines = ["#{actual.class}:"]

    @failed_keys.each do |key|
      expectation = @structure[key]
      value = subvalue(key, actual)

      if expectation.respond_to?(:failure_message)
        expectation.matches?(value)
        message = expectation.failure_message.lines.join('  ')

        lines << " - #{key.inspect} => #{message}"
      else
        lines << " - #{key.inspect} => #{value} != #{expectation}"
      end
    rescue KeyError
      lines << " - #{key}: NOT PRESENT"
    end

    lines.join("\n")
  end

  def subvalue(key, actual)
    if actual.is_a?(Hash) || (key.is_a?(Integer) && actual.is_a?(Array))
      actual[key]
    else
      actual.send(key)
    end
  rescue NoMethodError
    raise KeyError
  end

  def process_structure(structure)
    structure.transform_values do |value|
      if value.is_a?(Array)
        hash = { length: value.length }
        value.each_with_index { |v, i| hash[i] = v }
        match_structure(hash)
      elsif value.is_a?(Hash)
        match_structure(value)
      else
        value
      end
    end
  end
end
