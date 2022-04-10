# frozen_string_ltesteral: true

module Tests
  class Lexer < Base
    test "should lex simple queries" do
      tokens = tokenize <<~GQL
        query something {
          id
        }
      GQL
      expected_tokens = [[:EXPRESSION, 'query', "something"], [:FIELDSET], [:FIELD_NAME, "id"], [:END_FIELDSET]]
      expect(tokens).to eql(expected_tokens)
    end

    test "should lex nested queries" do
      tokens = tokenize <<~GQL
        query something {
          user { 
            id
            name
          }
        }
      GQL
      expected_tokens = [[:EXPRESSION, 'query', "something"], [:FIELDSET], [:FIELD_NAME, "user"], [:FIELDSET], [:FIELD_NAME, "id"], [:FIELD_NAME, "name"], [:END_FIELDSET], [:END_FIELDSET]]
      expect(tokens).to eql(expected_tokens)
    end

    test "should lex simple params" do
      tokens = tokenize <<~GQL
        query something(int: 1, string: "string", arr: [1,2,3], obj: { int: 1 }) {
          id
        }
      GQL
      expected_tokens = [
        [:EXPRESSION, 'query', "something"],
        [:START_ARGS],
        [:ARG_KEY, "int"],
        [:ARG_NUM_VALUE, 1],
        [:ARG_KEY, "string"],
        [:ARG_STRING_VALUE, "string"],
        [:ARG_KEY, "arr"],
        [:ARG_ARRAY],
        [:ARG_NUM_VALUE, 1],
        [:ARG_NUM_VALUE, 2],
        [:ARG_NUM_VALUE, 3],
        [:ARG_ARRAY_END],
        [:ARG_KEY, "obj"],
        [:ARG_HASH],
        [:ARG_KEY, "int"],
        [:ARG_NUM_VALUE, 1],
        [:ARG_HASH_END],
        [:END_ARGS],
        [:FIELDSET],
        [:FIELD_NAME, "id"],
        [:END_FIELDSET]
      ]
      expect(tokens).to eql(expected_tokens)
    end

    test "should lex special params" do
      tokens = tokenize <<~GQL
        query something($id: ID!) {
          name(id: $id) {
            user  
          }
        }
      GQL
      expected_tokens = [
        [:EXPRESSION, 'query', "something"],
        [:START_ARGS],
        [:SPECIAL_ARG_KEY, "id"],
        [:SPECIAL_ARG_VAL, "ID!"],
        [:END_ARGS],
        [:FIELDSET],
        [:FIELD_NAME, "name"],
        [:START_ARGS],
        [:ARG_KEY, "id"],
        [:SPECIAL_ARG_REF, "id"],
        [:END_ARGS],
        [:FIELDSET],
        [:FIELD_NAME, "user"],
        [:END_FIELDSET],
        [:END_FIELDSET]
      ]
      expect(tokens).to eql(expected_tokens)
    end

    test "should lex fragments and fragment refs" do
      tokens = tokenize <<~GQL
        query something {
          ...fragmentRef
        }
  
        fragment fragmentRef on Something {
          id
          name
        }
      GQL

      expected_tokens = [
        [:EXPRESSION, 'query', "something"],
        [:FIELDSET],
        [:FRAGMENT_REF, "fragmentRef"],
        [:END_FIELDSET],
        [:FRAGMENT, "fragmentRef", "Something"],
        [:FIELDSET],
        [:FIELD_NAME, "id"],
        [:FIELD_NAME, "name"],
        [:END_FIELDSET]
      ]
      expect(tokens).to eql(expected_tokens)
    end
  end
end