# frozen_string_literal: true

require_relative '../lib/graphlyte/lexer.rb'
require_relative '../lib/graphlyte/parser.rb'

require 'pry'
require "super_diff/rspec"


describe Graphlyte::Parser do
  describe 'bracket' do
    it 'parses a sequence surrounded by brackets' do
      gql = '{ a b c }'
      ts = Graphlyte::Lexer.lex(gql)
      p = Graphlyte::Parser.new(tokens: ts)

      names = p.bracket('{', '}') { p.parse_name }

      expect(names).to eq %w[a b c]
    end

    it 'supports a limit, raising an error when it is exceeded' do
      gql = '{ a b c }'
      ts = Graphlyte::Lexer.lex(gql)
      p = Graphlyte::Parser.new(tokens: ts)

      expect do
        p.bracket('{', '}', 2) { p.parse_name }
      end.to raise_error(/Unexpected token at 1:7-1:8: "c "/)
    end

    it 'supports a limit, accepting values that are within the limit' do
      gql = '{ a b } c'
      ts = Graphlyte::Lexer.lex(gql)
      p = Graphlyte::Parser.new(tokens: ts)

      names = p.bracket('{', '}', 2) { p.parse_name }
      following = p.parse_name

      expect(names).to eq %w[a b]
      expect(following).to eq 'c'
    end
  end

  describe 'parse_value' do
    it 'parses simple and compound values' do
      gql = <<~GQL
        !
        $ref $raf
        1
        1.2
        "some string"
        ENUM_VALUE
        true false null
        [0, 1, "foo", foo, [ true, false ]],
        { a: 0, b: 1, c: 2 }
        !
      GQL
      ts = Graphlyte::Lexer.lex(gql)
      p = Graphlyte::Parser.new(tokens: ts)

      values = p.bracket('!', '!') { p.parse_value }

      expect(values).to eq [
        Graphlyte::Syntax::VariableReference.new('ref'),
        Graphlyte::Syntax::VariableReference.new('raf'),
        Graphlyte::Syntax::NumericLiteral.new('1', nil, nil, false),
        Graphlyte::Syntax::NumericLiteral.new('1', '2', nil, false),
        'some string',
        Graphlyte::Syntax::EnumValue.new('ENUM_VALUE'),
        true,
        false,
        nil,
        [
          Graphlyte::Syntax::NumericLiteral.new('0', nil, nil, false),
          Graphlyte::Syntax::NumericLiteral.new('1', nil, nil, false),
          'foo',
          Graphlyte::Syntax::EnumValue.new('foo'),
          [true, false]
        ],
        {
          'a' => Graphlyte::Syntax::NumericLiteral.new('0', nil, nil, false),
          'b' => Graphlyte::Syntax::NumericLiteral.new('1', nil, nil, false),
          'c' => Graphlyte::Syntax::NumericLiteral.new('2', nil, nil, false)
        }
      ]
    end
  end

  it 'parses operations' do
    gql = <<-GQL
     query Foo($x: Int = 10) {
       currentUser @client {
         name(format: LONG), years: age @show(if: true)
       }
       thingy(id: $x) { foo }
     }
    GQL
    ts = Graphlyte::Lexer.lex(gql)
    p = Graphlyte::Parser.new(tokens: ts)

    q = p.operation

    expected = Graphlyte::Syntax::Operation.new(
      type: :query,
      name: 'Foo',
      variables: [
        Graphlyte::Syntax::VariableDefinition.new(
          variable: 'x',
          type: Graphlyte::Syntax::Type.new('Int'),
          default_value: Graphlyte::Syntax::NumericLiteral.new('10', nil, nil, false),
          directives: []
        )
      ],
      directives: [],
      selection: [
        Graphlyte::Syntax::Field.new(
          alias: nil,
          name: 'currentUser',
          arguments: nil,
          directives: [Graphlyte::Syntax::Directive.new('client', nil)],
          selection: [
            Graphlyte::Syntax::Field.new(
              alias: nil,
              name: 'name',
              arguments: [
                Graphlyte::Syntax::Argument.new('format', Graphlyte::Syntax::EnumValue.new('LONG'))
              ],
              directives: [],
              selection: nil
            ),
            Graphlyte::Syntax::Field.new(
              alias: 'years',
              name: 'age',
              arguments: nil,
              directives: [Graphlyte::Syntax::Directive.new(
                'show',
                [Graphlyte::Syntax::Argument.new("if", true)]
              )],
              selection: nil
            )
          ]
        ),
        Graphlyte::Syntax::Field.new(
          alias: nil,
          name: 'thingy',
          arguments: [
            Graphlyte::Syntax::Argument.new(
              'id',
              Graphlyte::Syntax::VariableReference.new('x')
            )
          ],
          directives: [],
          selection: [
            Graphlyte::Syntax::Field.new(
              alias: nil,
              name: 'foo',
              arguments: nil,
              directives: [],
              selection: nil
            )
          ]
        )
      ]
    )

    expect(q).to eq expected
  end
end
