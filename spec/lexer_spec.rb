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
      [:SEPARATOR],
      [:CONTENT, "U"],
      [:CONTENT, "s"],
      [:CONTENT, "e"],
      [:CONTENT, "r"],
      [:SEPARATOR],
      [:START_FIELDSET],
      [:SEPARATOR],
      [:CONTENT, "n"],
      [:CONTENT, "a"],
      [:CONTENT, "m"],
      [:CONTENT, "e"],
      [:SEPARATOR],
      [:END_FIELDSET],
      [:SEPARATOR],
      [:END_FIELDSET],
      [:SEPARATOR]
    ]
    tokens = Graphlyte::Parsing::Lexer.tokenize(str)
    expect(tokens).to eql(expected)

  end
end
