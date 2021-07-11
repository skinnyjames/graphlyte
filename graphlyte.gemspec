Gem::Specification.new do |s|
  s.name        = 'graphlyte'
  s.version     = '0.1.3'
  s.licenses    = ['MIT']
  s.summary     = "craft graphql queries with ruby"
  s.description = "craft graphql queries with ruby"
  s.authors     = ["Sean Gregory"]
  s.email       = 'sean.christopher.gregory@gmail.com'
  s.files       = Dir['lib/**/*.rb']
  s.require_paths = ['lib']
  s.homepage    = 'https://rubygems.org/gems/graphlyte'
  s.metadata    = { "source_code_uri" => "https://github.com/skinnyjames/graphlyte" }
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rest-client'
end