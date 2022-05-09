require 'graphlyte'
require 'rest-client'

# The kind of thing that is represented in the schema
# Entities can be searched for and loaded from JSON responses.
module Entity
  def assign(attr, value)
    attr = attr.to_sym
    if (klass = self.class.connections[attr])
      value = Mapper.new(klass).build_from(value)
    elsif !self.class.record_fields.any? { _1 == attr || Array(_1).first == attr }
      return
    end

    send(:"#{attr.downcase}=", value)
  end

  def assign_all(attrs)
    attrs.each { |k, v| assign(k, v) }
  end

  def self.included(mod)
    mod.define_singleton_method :mapper do
      @mapper ||= Mapper.new(self)
    end
  end
end

# An author entity
class Author
  include Entity

  attr_accessor :name

  def self.record_fields
    %i[name]
  end

  def self.connections
    {}
  end
end

# A book entity
class Book
  include Entity

  attr_accessor :title, :author, :isbn, :published

  def self.record_fields
    [:title, :published, %i[isbn id]]
  end

  def self.connections
    { author: Author }
  end
end

# How to load an Entity from a response
class Mapper
  def initialize(entity_class)
    @entity_class = entity_class
  end

  def build_from(data)
    return unless data

    entity = @entity_class.new
    entity.assign_all(data)
    entity
  end
end

class Store
  def initialize(entity_class)
    @entity_class = entity_class
  end

  def load(id)
    query = Graphlyte.query do |q|
      select_entity(q, @entity_class, id: id).alias(:_)
    end

    data = Http.new.post(query)['_']

    @entity_class.mapper.build_from(data)
  end

  private

  def select_entity(node, entity_class, **args)
    node.select!(entity_class.name, **args) do |child|
      entity_class.record_fields.each do |field|
        case field
        when Array
          child.select!(field.last).alias(field.first)
        else
          child.select!(field)
        end
      end
      entity_class.connections.each do |name, klass|
        select_entity(child, klass).alias(name)
      end
    end
  end
end

Books = Store.new(Book)
Authors = Store.new(Author)

class Http
  def initialize
    @host = ENV.fetch('RC_HOST', 'localhost')
    @port = ENV.fetch('RC_PORT', '3000')
    @uri = "http://#{@host}:#{@port}/raw"
    @headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def post(query)
    json = query.request_body
    JSON.parse(RestClient.post(@uri, json, @headers))['data']
  rescue RestClient::ExceptionWithResponse => e
    body = JSON.parse(e.response.body)
    raise body.fetch('errors', [{ 'message' => 'boom' }]).map { _1['message'] }.join(', ')
  end
end
