# frozen_string_literal: true

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 2.7.0'
  s.name        = 'graphlyte'
  s.version     = '1.0.0'
  s.licenses    = ['MIT']
  s.summary     = 'craft graphql queries with ruby'
  s.description = 'craft graphql queries with ruby'
  s.authors     = ['Sean Gregory', 'Alex Kalderimis']
  s.email       = 'alex.kalderimis@gmail.com'
  s.files       = Dir['lib/**/*.rb']
  s.require_paths = ['lib']
  s.homepage    = 'https://rubygems.org/gems/graphlyte'
  s.metadata    = { 'source_code_uri' => 'https://gitlab.com/skinnyjames/graphlyte',
                    'rubygems_mfa_required' => 'true' }
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rest-client'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-cobertura'
  s.add_development_dependency 'super_diff'
end
