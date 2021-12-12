module Graphlyte
  module Schema
    module Types
      class Defaults
        attr_reader :value
        def initialize(value)
          @value = value
        end

        def merge!(str)
          parse_value(@value, str)
        end

        def parse_value(value, str)
          if value.is_a?(Hash)
            str << "{ "
            value.each_with_index do |(k, v), idx|
              str << "#{k}: "
              parse_value(v, str)
              str << ", " if idx < (value.size - 1)
            end
            str << " }"
          elsif value.is_a?(Array)
            str << "["
            value.each_with_index do |item, idx|
              parse_value(item, str)
              str << ", " if idx < (value.size - 1)
            end
            str << "]"
          else
            str << "#{Arguments::Value.new(value).to_s}"
          end
        end
      end

      class Base
        attr_reader :name, :placeholder

        def initialize(name, placeholder, defaults=nil)
          @name = name
          @placeholder = placeholder
          @defaults = defaults
        end

        def default
          return nil if @defaults.class == NilClass
          Defaults.new(@defaults)
        end
      end
    end
  end
end