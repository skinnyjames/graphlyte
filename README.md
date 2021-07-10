# graphlyte
[![Build Status](http://drone.skinnyjames.net/api/badges/skinnyjames/graphlyte/status.svg)](http://drone.skinnyjames.net/skinnyjames/graphlyte)

Craft composable graphql queries using ruby

## installation

in your Gemfile

`gem "graphlyte"`

## usage

```ruby
# Basic query
query = Graphlyte.query do |q|
  q.allTodos do |q|
    # specify fields for your query
    q.id
    q.status
    q.title
  end
end

puts query.to_s
```
outputs 
```
{
  allTodos{
    id
    status
    title  
  }
}
```

Send it across the wire

```ruby
require "rest-client" #or whatever api client you wish

RestClient.post("http://localhost", query.to_json, { "Content-Type" => "application/json"})
```

## examples

### Fragments / Nested Fragments

```ruby
extra_fields = Graphlyte.fragment('extraFields', "Todo") do |f|
  f.id
  f.status
end

todo = Graphlyte.fragment('todoFields', "Todo") do |f|
  f.title
  f << extra_fields
end

query = Graphlyte.query do |q|
  q.allTodos todo
end

puts query.to_s
```
returns
```
{
  allTodos{
    ...todoFields      
  }
}

fragment todoFields on Todo {
  title
  ...extraFields  
}
fragment extraFields on Todo {
  id
  status
}
```

### input and aliases

```ruby
query = Graphlyte.query do |q|
  q.User(id: 123).alias("sean") do |u|
    u.id
  end
  q.User(id: 456).alias("bob") do |u|
    u.id
  end
end

puts query.to_s
```
returns 
```
{
  sean: User(id: 123) {
    id  
  }
  bob: User(id: 456) {
    id  
  }
}
```
# purpose
This library aims to be a client agnostic implementation for building graphql queries.

By using Fragments and fieldsets, one can export structure resuable components for use in sophisticated queries

# todo
* more documentation
* refactor
* support mutations
* support schema validation

# running tests
`docker-compose build && docker-compose run test rspec`
