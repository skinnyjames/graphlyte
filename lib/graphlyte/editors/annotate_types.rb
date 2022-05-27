# frozen_string_literal: true

module Graphlyte
  module Editors
    # Use a schema definition to annotate the type of each field and variable reference.
    class AnnotateTypes
      TypeCheckError = Class.new(StandardError)
      TypeNotFound = Class.new(TypeCheckError)
      FieldNotFound = Class.new(TypeCheckError)
      CannotDetermineTypeName = Class.new(TypeCheckError)

      def initialize(schema, recheck: false)
        @schema = schema
        @recheck = recheck
      end

      def edit(doc)
        return if !recheck && doc.schema # Previously annotated

        doc.schema = @schema
        editor.edit(doc)
      end

      def editor
        @editor ||=
          Editor
          .top_down
          .on_field { |field, action| infer_field(field, action.parent, action.document) }
          .on_variable_reference do |ref, action|
            infer_ref(ref, action.closest(Syntax::Argument), action.closest(Syntax::Field))
          end
      end

      # For now we are ignoring variables nested in input objects.
      # TODO: encode input objects differently?
      def infer_ref(ref, argument, field)
        type = @schema.types[field.type.unpack]
        arg = type.arguments[argument.name]
        raise ArgumentNotFound, "#{type.name}.#{field.name}(#{argument.name})" unless arg

        ref.inferred_type = Syntax::Type.from_type_ref(arg.type)
      end

      def infer_field(field, parent, document)
        name = object_name(parent, document)
        object_type = type(name)

        raise FieldNotFound, "#{object_name}.#{field.name}" unless object_type.fields.key?(field.name)

        field.type = Syntax::Type.from_type_ref(object_type.fields[field.name].type)
      end

      def type(name)
        object_type = @schema.types[name]
        raise TypeNotFound, object_name unless object_type

        object_type
      end

      def object_name(parent, document)
        case parent
        when Syntax::FragmentSpread
          fragment = document.fragments[parent.name]
          raise CannotDetermineTypeName, parent unless fragment

          fragment.type_name
        when Syntax::InlineFragment, Syntax::Fragment
          parent.type_name
        when Syntax::Field
          parent.type.unpack
        end
      end
    end
  end
end
