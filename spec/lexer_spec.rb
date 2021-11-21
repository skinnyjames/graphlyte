describe Graphlyte::Schema::Lexer, :parser do
  it "should lex simple queries" do
    tokens = tokenize <<~GQL
      query something {
        id
      }
    GQL
    expected_tokens = [[:START_QUERY, "something"], [:FIELD_NAME, "id"], [:END_QUERY]]
    expect(tokens).to eql(expected_tokens)
  end

  it "should lex nested queries" do
    tokens = tokenize <<~GQL
      query something {
        user { 
          id
          name
        }
      }
    GQL
    expected_tokens = [[:START_QUERY, "something"], [:FIELD_NAME, "user"], [:START_FIELD], [:FIELD_NAME, "id"], [:FIELD_NAME, "name"], [:END_FIELD], [:END_QUERY]]
    expect(tokens).to eql(expected_tokens)
  end

  it "should lex simple params" do
    tokens = tokenize <<~GQL
      query something(int: 1, string: "string", arr: [1,2,3], obj: { int: 1 }) {
        id
      }
    GQL
    expected_tokens = [
      [:START_QUERY, "something"],
      [:START_ARGS],
      [:ARG_KEY, "int"],
      [:ARG_NUM_VALUE, 1],
      [:ARG_KEY, "string"],
      [:ARG_STRING_VALUE, "string"],
      [:ARG_KEY, "arr"],
      [:ARG_ARRAY_START],
      [:ARG_NUM_VALUE, 1],
      [:ARG_NUM_VALUE, 2],
      [:ARG_NUM_VALUE, 3],
      [:ARG_ARRAY_END],
      [:ARG_KEY, "obj"],
      [:ARG_HASH_START],
      [:ARG_KEY, "int"],
      [:ARG_NUM_VALUE, 1],
      [:ARG_HASH_END],
      [:END_ARGS],
      [:FIELD_NAME, "id"],
      [:END_QUERY]
    ]
    expect(tokens).to eql(expected_tokens)
  end

  it "should lex special params" do
    tokens = tokenize <<~GQL
      query something($id: ID!) {
        name(id: $id) {
          user  
        }
      }
    GQL
    expected_tokens = [
      [:START_QUERY, "something"],
      [:START_ARGS],
      [:SPECIAL_ARG_KEY, "id"],
      [:SPECIAL_ARG_VAL, "ID!"],
      [:END_ARGS],
      [:FIELD_NAME, "name"],
      [:START_ARGS],
      [:ARG_KEY, "id"],
      [:SPECIAL_ARG_REF, "id"],
      [:END_ARGS],
      [:START_FIELD],
      [:FIELD_NAME, "user"],
      [:END_FIELD],
      [:END_QUERY]
    ]
    expect(tokens).to eql(expected_tokens)
  end

  it "should lex fragments and fragment refs" do
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
      [:START_QUERY, "something"],
      [:FRAGMENT_REF, "fragmentRef"],
      [:END_QUERY],
      [:START_FRAGMENT, "fragmentRef", "Something"],
      [:FIELD_NAME, "id"],
      [:FIELD_NAME, "name"],
      [:END_FRAGMENT]
    ]
    expect(tokens).to eql(expected_tokens)
  end
end