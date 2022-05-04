# frozen_string_literal: true

require 'set'

module Graphlyte
  # Very simplistic data-class. Inheritance is not modelled.
  class Data
    def self.attr_accessor(*names)
      super
      self.attributes.merge(names)
    end

    def self.attr_reader(*names)
      super
      self.attributes.merge(names)
    end

    def self.attributes
      @attrs ||= [].to_set
    end

    # Permissive constructor: ignores unknown attributes
    def initialize(**kwargs)
      self.class.attributes.each do |arg|
        self.send(:"#{arg}=", kwargs[arg]) if kwargs.key?(arg)
      end
    end

    def eql?(other)
      other.is_a?(self.class) && state == other.send(:state)
    end

    def ==(other)
      eql?(other)
    end

    def hash
      state.hash
    end

    def dup
      self.class.new(**self.class.attributes.to_h { [_1, dup_attribute(_1)] })
    end

    private def dup_attribute(attr)
      value = send(attr)

      case value
      when Array
        value.map(&:dup)
      when Hash
        value.transform_values(&:dup)
      else
        value.dup
      end
    end

    def inspect
      "#<#{self.class} #{self.class.attributes.map { "@#{_1}=#{send(_1).inspect}" }.join(' ')}>"
    end

    private def state
      self.class.instance_variable_get(:@attrs).map { send _1 }
    end
  end
end
