describe Graphlyte::Parsing do 
  it "should lex simple fields" do 
    str = <<~GRAPHQL
      { 
        User { 
          name
        }
      }
    GRAPHQL
    expected = [
      [:START_FIELDSET],
      [:CONTENT, "User"],
      [:START_FIELDSET],
      [:CONTENT, "name"],
      [:END_FIELDSET],
      [:END_FIELDSET],
    ]
    tokens = Graphlyte::Parsing::Lexer.tokenize(str)
    expect(tokens).to eql(expected)

  end
end
