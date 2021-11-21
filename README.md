# graphlyte

[![Build Status](http://drone.skinnyjames.net/api/badges/seanchristophergregory/graphlyte/status.svg?ref=refs/heads/main)](http://drone.skinnyjames.net/seanchristophergregory/graphlyte)

[api docs](https://seanchristophergregory.gitlab.io/graphlyte/)

Craft composable graphql queries using ruby

## installation

in your Gemfile

`gem "graphlyte"`

## usage

```ruby
# Basic query
query = Graphlyte.query do
  all_todos do
    # specify fields for your query
    id
    status
    title
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
extra_fields = Graphlyte.fragment('extraFields', "Todo") do
  id
  status
end

# pass a block parameter if you want to merge/spread fieldsets or fragments
todo = Graphlyte.fragment('todoFields', "Todo") do |f|
  f.title
  f << extra_fields
end

query = Graphlyte.query do
  all_todos todo
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
query = Graphlyte.query do
  User(id: 123).alias("sean") do
    id
  end
  User(id: 456).alias("bob") do
    id
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
# variables
```ruby
query = Graphlyte.query do 
  all_todos(per_page: :per_page, page: :pages) do
    status
    title 
  end
end

query.to_json(per_page: 1, pages: 1)
```
returns 

```
{
  "query": "query anonymousQuery($perPage: Int, $pages: Int) {
              allTodos(perPage: $perPage, page: $pages) {
                status     
                title    
              }
            },
  "variables":{"perPage":1,"pages":1}
}
```

## complex types

Graphlyte will try to infer the types of primitive values, but if the value is an ID, or other non-primitive, you can use `Graphlyte::TYPES`

```ruby

fragment = Graphlyte.fragment("userFields", "Query") do 
  User(id: Graphlyte::TYPES.ID!(:sean_id)) do
    name         
  end
end

query = Graphlyte.query do |f|
  all_todos(filter: Graphlyte::TYPES.TodoFilter(:todo_filter)) do
    status
    title
  end
  f << fragment
end

query.to_json(todo_filter: { ids: [1]}, sean_id: 123)
```
returns 
```json
{
  "query":"query anonymousQuery($todoFilter: TodoFilter, $seanId: ID!) {
                    allTodos(filter: $todoFilter) {
                      status
                      title
                    }
                   ...userFields 
                   }
                   
                   fragment userFields on Query {
                      User(id: $seanId) {
                        name
                      }
                    }",
  "variables":{"todoFilter":{"ids":[1]},"seanId":123}
}
```

## getting placeholders for a query

you can call `query.placeholders` on a query to get back all of the expected variables.  This is useful when you don't know all of the variables that a query expects.


### mutations

you can call Graphlyte::mutation like you would Graphlyte::query. 

# parsing

there is rudimentary support for parsing
see `spec/parser_spec.rb` for more details

# purpose
This library aims to be a client agnostic implementation for building graphql queries.

By using Fragments and fieldsets, one can export structure resuable components for use in sophisticated queries

# todo
* more documentation
* refactor
* support schema validation

# running tests
`docker-compose build && docker-compose run test rspec`
