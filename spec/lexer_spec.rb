# frozen_string_literal: true

require_relative '../lib/graphlyte/lexer.rb'

describe Graphlyte::Lexer do
  it 'ignores commas, but treats them as breaks' do
    tokens = tokenize('0,1,2,3,4')

    expected_tokens = [
      [:NUMBER, '0'],
      [:NUMBER, '1'],
      [:NUMBER, '2'],
      [:NUMBER, '3'],
      [:NUMBER, '4']
    ]

    expect(tokens.take(5)).to eql(expected_tokens)
  end

  it 'handles names, numbers, strings and punctuation (ignoring comments and commas)' do
    tokens = tokenize(<<~GQL)
      # all the tokens we need to lex:
      foo bar __typename zip123                         # names
      baz, bim, boop                                    # comma separated
      0 -0 -1 0.10 123 -123 3.145 1.2e100 -3E10 1e-10      # various numbers
      "foo" "bar \\"# rab" "\\t\\n\\\\" "foo, bar, baz" # strings
      {}()@ # assorted word-salad
    GQL

    expected_tokens = [
      [:NAME, 'foo'],
      [:NAME, 'bar'],
      [:NAME, '__typename'],
      [:NAME, 'zip123'],
      [:NAME, 'baz'],
      [:NAME, 'bim'],
      [:NAME, 'boop'],
      [:NUMBER, '0'],
      [:NUMBER, '-0'],
      [:NUMBER, '-1'],
      [:NUMBER, '0.10'],
      [:NUMBER, '123'],
      [:NUMBER, '-123'],
      [:NUMBER, '3.145'],
      [:NUMBER, '1.2e100'],
      [:NUMBER, '-3e10'],
      [:NUMBER, '1e-10'],
      [:STRING, "foo"],
      [:STRING, %q(bar "# rab)],
      [:STRING, %Q(\t\n\\)],
      [:STRING, %Q(foo, bar, baz)],
      [:PUNCTATOR, '{'],
      [:PUNCTATOR, '}'],
      [:PUNCTATOR, '('],
      [:PUNCTATOR, ')'],
      [:PUNCTATOR, '@'],
      [:EOF, nil]
    ]

    expect(tokens).to eql(expected_tokens)
  end

  it 'handles block quotes' do
    tokens = tokenize(<<~GQL)
      123 """
        foo bar
          biz baz boz
          "says who?"
          \\"""
        bop
      """ 456
    GQL

    str = [
      'foo bar',
      '  biz baz boz',
      '  "says who?"',
      '  """',
      'bop'
    ].join("\n")

    expected_tokens = [
      [:NUMBER, '123'],
      [:STRING, str],
      [:NUMBER, '456'],
      [:EOF, nil]
    ]

    expect(tokens).to eql(expected_tokens)
  end

  it "should lex queries" do
    tokens = tokenize(<<~GQL)
      query something($var: Type!) {
        id @client
        thingy(arg: value, x: ONE, y: "TWO", z: 3, things: [1,2,3]) {
          alias: field1, field2, field3
        }
      }
    GQL

    expected_tokens = [
      [:NAME, 'query'],
      [:NAME, 'something'],
      [:PUNCTATOR, "("],
      [:PUNCTATOR, "$"],
      [:NAME, "var"],
      [:PUNCTATOR, ":"],
      [:NAME, "Type"],
      [:PUNCTATOR, "!"],
      [:PUNCTATOR, ")"],
      [:PUNCTATOR, "{"],
      [:NAME, "id"],
      [:PUNCTATOR, "@"],
      [:NAME, "client"],
      [:NAME, "thingy"],
      [:PUNCTATOR, "("],
      [:NAME, "arg"],
      [:PUNCTATOR, ":"],
      [:NAME, "value"],
      [:NAME, "x"],
      [:PUNCTATOR, ":"],
      [:NAME, "ONE"],
      [:NAME, "y"],
      [:PUNCTATOR, ":"],
      [:STRING, "TWO"],
      [:NAME, "z"],
      [:PUNCTATOR, ":"],
      [:NUMBER, "3"],
      [:NAME, "things"],
      [:PUNCTATOR, ":"],
      [:PUNCTATOR, "["],
      [:NUMBER, "1"],
      [:NUMBER, "2"],
      [:NUMBER, "3"],
      [:PUNCTATOR, "]"],
      [:PUNCTATOR, ")"],
      [:PUNCTATOR, "{"],
      [:NAME, "alias"],
      [:PUNCTATOR, ":"],
      [:NAME, "field1"],
      [:NAME, "field2"],
      [:NAME, "field3"],
      [:PUNCTATOR, "}"],
      [:PUNCTATOR, "}"],
      [:EOF, nil]
    ]

    expect(tokens).to eql(expected_tokens)
  end

  it 'raises errors on unterminated strings' do
    expect do
      tokenize('foo "bar 123')
    end.to raise_error(Graphlyte::LexError)
  end

  it 'raises errors on bad numeric formats' do
    expect do
      tokenize('123. bad')
    end.to raise_error(Graphlyte::LexError)
  end

  def tokenize(src)
    described_class.lex(src).map { [_1.type, _1.value&.to_s] }
  end
end
