# frozen_string_literal: true

require_relative '../lib/graphlyte/lexer.rb'
require_relative '../lib/graphlyte/parser.rb'

require 'pry'
require "super_diff/rspec"


describe Graphlyte::Parser do
  describe 'expect' do
    it 'asserts that the next token matches a literal' do
      p = parser('a b c')

      a = p.expect(:NAME, 'a')
      b = p.expect(:NAME, 'b')

      expect([a, b]).to eq %w[a b]

      expect { p.expect(:NAME, 'd') }.to raise_error(Graphlyte::Expected)
    end
  end

  describe 'optional' do
    it 'backtracks on failure' do
      p = parser('! [ {')

      # succeeds
      bang = p.optional { p.expect(:PUNCTATOR, '!') }
      # partially succeeds, but fails in total, and thus backtracks
      brackets = p.optional do
        p.expect(:PUNCTATOR, '[') + p.expect(:PUNCTATOR, '[')
      end
      # proof that we didn't advance after the first success
      brace = p.optional { p.expect(:PUNCTATOR, '{') }
      bracket = p.optional { p.expect(:PUNCTATOR, '[') }

      expect([bang, brackets, brace, bracket]).to eq ['!', nil, nil, '[']
    end
  end

  describe 'one_of' do
    it 'selects from alternatives, defined as closures' do
      p = parser('X')

      r = p.one_of(
        ->{ p.expect(:PUNCTATOR, '!') },
        ->{ 'got ' + p.expect(:NAME, 'X') },
        ->{ raise 'BANG' }
      )

      expect(r).to eq 'got X'
    end

    it 'selects from alternatives, using method names' do
      greek = Class.new(described_class) do
        def a
          expect(:NAME, 'a')
          :alpha
        end

        def b
          expect(:NAME, 'b')
          :beta
        end

        def c
          expect(:NAME, 'c')
          :gamma
        end
      end

      p = parser('b c a', klass: greek)

      x = p.one_of(:a, :b, :c)
      y = p.one_of(:a, :b, :c)

      expect([x, y]).to eq %i[beta gamma]

      expect { p.one_of(:b, :c) }.to raise_error(Graphlyte::Expected)
    end
  end

  describe 'many' do
    it 'parses zero or more repetitions, up to EOF' do
      p = parser('a b c d e')

      names = p.many { p.parse_name }

      expect(names).to eq %w[a b c d e]
    end

    it 'parses zero or more repetitions' do
      p = parser('a b c d e 1 2 3!')

      names = p.many { p.parse_name }
      nums = p.many { p.expect(:NUMBER) }
      strings = p.many { p.expect(:STRING) }

      expect(names).to eq %w[a b c d e]
      expect(nums.map(&:to_i)).to eq [1, 2, 3]
      expect(strings).to be_empty
    end

    it 'supports a limit' do
      p = parser('a b c d e 1 2 3!')

      names = p.many(limit: 3) { p.parse_name }

      expect(names).to eq %w[a b c]
    end
  end

  describe 'some' do
    it 'parses one or more repetitions' do
      p = parser('a b c d e 1 2 3!')

      names = p.some { p.parse_name }
      nums = p.some { p.expect(:NUMBER) }

      expect(names).to eq %w[a b c d e]
      expect(nums.map(&:to_i)).to eq [1, 2, 3]

      expect { p.some { p.expect(:STRING) } }.to raise_error(Graphlyte::ParseError)
    end
  end

  describe 'bracket' do
    it 'parses a parse surrounded by brackets' do
      p = parser('{ a b c } d e f')

      names = p.bracket('{', '}') { p.some { p.parse_name } }

      expect(names).to eq %w[a b c]
    end
  end

  describe 'parse_value' do
    it 'parses simple and compound values' do
      p = parser(<<~GQL)
        $ref $raf
        1
        1.2
        "some string"
        ENUM_VALUE
        true false null
        [0, 1, "foo", foo, [ true, false ]],
        { a: 0, b: 1, c: 2 }
      GQL

      values = p.some { p.parse_value }

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

  context 'when fields are deeply nested' do
    let(:gql) do
      <<-GQL
      query {
        a { b { c { d { e { f { g { h { i { j { k { l { m { n { o
          }   }   }   }   }   }   }   }   }   }   }   }   }   }
      }
      GQL
    end

    it 'parses deeply nested fields' do
      p = parser(gql)

      q = p.operation

      expect(selection_hash(q.selection)).to eq({
        a: { b: { c: { d: { e: { f: { g: { h: { i: { j: { k: { l: { m: { n: { o: {} } } } } } } } } } } } } } }
      })
    end

    it 'enforces a depth limit' do
      p = parser(gql)
      p.max_depth = 3

      expect { p.operation }.to raise_error(Graphlyte::TooDeep)
    end

    it 'enforces a depth limit, allowing shallower queries' do
      p = parser('query { a { b { c } } }')
      p.max_depth = 3

      expect(selection_hash(p.operation.selection)).to eq({
        a: { b: { c: {} } }
      })
    end

    def selection_hash(selection)
      selection.to_h do |fld|
        [fld.name.to_sym, selection_hash(fld.selection)]
      end
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
    p = parser(gql)

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

  def parser(gql, klass: described_class)
    ts = Graphlyte::Lexer.lex(gql)
    klass.new(tokens: ts)
  end
end
