# Graphlyte

[![Coverage report](https://gitlab.com/skinnyjames/graphlyte/badges/main/coverage.svg?job=rspec)](https://skinnyjames.gitlab.io/graphlyte)

Craft composable GraphQL queries using a Ruby DSL.

Parse GraphQL documents into a simple Ruby AST.

Manipulate, inspect and transform GraphQL documents as data, not opaque strings.

## Installation

in your Gemfile

`gem "graphlyte"`

## [Builder DSL](docs/Builder_DSL.md)

Queries can be constructed using the selection-builder DSL. This involves
defining blocks that receive a `SelectionBuilder` object and using that to
build a selection. The builder supports a method-missing based API that allows
fields to be named directly for convenience.

```ruby
# Basic query
query = Graphlyte.query do |q|
  q.all_todos do |todo|
    # specify fields for your query, using method-missing
    todo.id
    todo.status
    todo.title

    # or pass field names as values
    todo.select!(:open)
  end
end

puts query
```

produces:

```graphql
query {
  allTodos { id status title open }
}
```

Send it across the wire

```ruby
require "rest-client" #or whatever api client you wish

RestClient.post("http://localhost", query.request_body, { "Content-Type" => "application/json"})
```

### Fragments / Nested Fragments

```ruby
extra_fields = Graphlyte.fragment('extraFields', on: "Todo") do |todo|
  todo.id
  todo.status
end

# pass a block parameter if you want to merge/spread fieldsets or fragments
todo = Graphlyte.fragment('todoFields', on: "Todo") do |f|
  f.title
  f << extra_fields
end

query = Graphlyte.query do |q|
  q.all_todos todo
end

puts query
```

produces:

```graphql
query {
  allTodos {
    ...todoFields
  }
}

fragment todoFields on Todo {
  title
  ...extraFields
}

fragment extraFields on Todo { id status }
```

### Input arguments and aliases

Arguments may be passed as plain Ruby values, and aliases specified
with `alias`:

```ruby
query = Graphlyte.query do |q|
  q.User(id: 123).alias("sean") do
    _1.id
  end
  q.User(id: 456).alias("bob") do
    _1.id
  end
end

puts query
```

Produces:

```graphql
query {
  sean: User(id: 123) { id }
  bob: User(id: 456) { id }
}
```

### Variables

Symbols as arguments indicate a named, un-typed variable. Variable
type is determined when you pass an argument value to it:

```ruby
query = Graphlyte.query do |q|
  q.all_todos(per_page: :per_page, page: :pages) do
    q.status
    q.title
  end
end

puts query.request_body(per_page: 1, pages: 1)
```

Produces:

```json
{
  "query": "query($perPage: Int!, $pages: Int!) {\n  status\n  title\n allTodos(perPage: $perPage , page: $pages)\n}",
  "variables":{"perPage":1,"pages":1}
}
```

If the argument value is not a Ruby primitive, or it does not map
to the expected type, variables can be defined explicitly:

```ruby
sean_id = Graphlyte.var('ID', :sean_id)

sean = Graphlyte.fragment("userFields", on: "Query") do |q|
  q.User(id: sean_id, &:name)
end

query = Graphlyte.query do |q|
  q.all_todos(filter: Graphlyte.var('TodoFilter', :filter)) do |t|
    t.status
    t.title
  end

  q << sean
end

puts query.request_body(filter: { ids: [1]}, sean_id: 123)
```

Produces:

```json
{
  "query":"query($filter: TodoFilter, $seanId: ID) {\n  allTodos(filter: $filter) { status title}\n  ...userFields\n}\n\nfragment userFields on Query {\n  User(id: $seanId) { name }\n}",
  "variables":{"filter":{"ids":[1]},"seanId":123}
}
```

### `Graphlyte::Selector`: modifying queries

The selector class provides path-based modification of queries:

```ruby
query = Graphlyte.parse(<<~GQL)
  query name($projectPath: ID!, $commitSha: String) {
    project(fullPath: $projectPath, sha: $commitSha) {
      createdAt
      pipelines(sha: $commitSha) {
        nodes {
          status
        }
      }
    }
  }
GQL

selector = Graphlyte::Selector.new.
  at('project.pipelines.nodes.status', &:remove).
  at('project.pipelines.nodes') do |node| node.append do |n|
      n.downstream { |ds| ds.nodes(&:active) }
    end
  end

puts selector.edit(query)
```

Produces:

```graphql
query name($projectPath: ID!, $commitSha: String) {
  project(fullPath: $projectPath, sha: $commitSha) {
    createdAt
    pipelines(sha: $commitSha) {
      nodes {
        downstream {
          nodes { active }
        }
      }
    }
  }
}
```

## [Introspection](Introspection)

### Listing variables

Call `Document#variable_references` to list all the used variables.  This is useful when you don't know all of the variables that a query expects.

Example:

```ruby
doc = Graphlyte.parse(<<~GQL)
  query Pipelines($projectPath: ID!, $commitSha: String) {
    project(fullPath: $projectPath) {
      createdAt
      pipelines(sha: $commitSha) {
        nodes { ...pipelineFields }
      }
    }
  }

  mutation StopPipeline($id: ID!) {
    stopPipeline(id: $id) {
      errors
      pipeline { ...pipelineFields }
    }
  }

  fragment pipelineFields on Pipeline {
      id
      status
  }
GQL

puts doc.variable_references['Pipelines'].map(&:variable).inspect
puts doc.variable_references['StopPipeline'].map(&:variable).inspect
```

Produces:

```
["projectPath", "commitSha"]
["id"]
```

## Parsing

There is full parsing support for the GraphQL specification. Call
`Graphlyte.parse` to parse GraphQL text documents. See
[`Graphlyte::Syntax`](./lib/graphlyte/syntax.rb) for definitions of the AST.

## Purpose

This library aims to be a client agnostic implementation for parsing, building,
inspecting and manipulating GraphQL documents.

## Todo

* more documentation
* support schema validation

## Running tests

`rspec`
