# frozen_string_literal: true

describe Graphlyte::Refinements::StringRefinement do
  using Graphlyte::Refinements::StringRefinement

  it 'transforms snake_case to camelCase' do
    expect('snake_case'.camelize).to eq 'snakeCase'
  end

  it 'handles the empty string' do
    expect(''.camelize).to eq ''
  end

  it 'does not transform _' do
    expect('_'.camelize).to eq '_'
  end

  it 'handles prefixes' do
    expect('__foo_bar'.camelize).to eq '__fooBar'
  end

  it 'handles suffixes' do
    expect('foo_bar__'.camelize).to eq 'fooBar__'
  end

  it 'handles affixes' do
    expect('__foo_bar__'.camelize).to eq '__fooBar__'
  end
end
