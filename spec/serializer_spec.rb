# frozen_string_literal: true

describe Graphlyte::Serializer do
  let(:true_value) do
    Graphlyte::Syntax::Value.new(Graphlyte::Syntax::TRUE, :BOOL)
  end

  let(:false_value) do
    Graphlyte::Syntax::Value.new(Graphlyte::Syntax::FALSE, :BOOL)
  end

  let(:null_value) do
    Graphlyte::Syntax::Value.new(Graphlyte::Syntax::NULL, :NULL)
  end

  it 'can serialize a representative query' do
    fragment = Graphlyte::Syntax::Fragment.new(
      name: 'someFields',
      type_name: 'Thing',
      directives: [Graphlyte::Syntax::Directive.new('awesome')],
      selection: [
        Graphlyte::Syntax::Field.new(name: 'thingField')
      ]
    )

    operation = Graphlyte::Syntax::Operation.new(
      type: :query,
      name: 'Foo',
      variables: [
        Graphlyte::Syntax::VariableDefinition.new(
          variable: 'x',
          type: Graphlyte::Syntax::Type.new('Int'),
          default_value: int('10'),
          directives: []
        ),
        Graphlyte::Syntax::VariableDefinition.new(
          variable: 'y',
          type: Graphlyte::Syntax::Type.new('Weight', non_null: true),
          default_value: nil,
          directives: []
        )
      ],
      directives: [],
      selection: [
        Graphlyte::Syntax::FragmentSpread.new(name: 'someFields'),
        Graphlyte::Syntax::Field.new(
          as: nil,
          name: 'currentUser',
          arguments: [],
          directives: [Graphlyte::Syntax::Directive.new('client', nil)],
          selection: [
            Graphlyte::Syntax::Field.new(
              as: nil,
              name: 'name',
              arguments: [
                Graphlyte::Syntax::Argument.new('format', enum(:LONG)),
                Graphlyte::Syntax::Argument.new('gravity', Graphlyte::Syntax::VariableReference.new(variable: 'y'))
              ],
              directives: [],
              selection: []
            ),
            Graphlyte::Syntax::Field.new(
              as: 'years',
              name: 'age',
              arguments: [],
              directives: [Graphlyte::Syntax::Directive.new(
                'show',
                [Graphlyte::Syntax::Argument.new('if', true_value)]
              )],
              selection: []
            )
          ]
        ),
        Graphlyte::Syntax::Field.new(
          as: nil,
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
              as: nil,
              name: 'foo',
              arguments: [],
              directives: [],
              selection: []
            )
          ]
        )
      ]
    )

    buff = []
    described_class.new(buff).dump_definitions([operation, fragment])

    expected = <<~GQL.strip
      query Foo($x: Int = 10, $y: Weight!) {
        ...someFields
        currentUser @client {
          name(format: LONG, gravity: $y)
          years: age @show(if: true)
        }
        thingy(id: $x) { foo }
      }

      fragment someFields on Thing @awesome { thingField }
    GQL

    expect(buff.join.strip).to eq(expected)
  end

  def int(str)
    Graphlyte::Syntax::Value.new(
      Graphlyte::Syntax::NumericLiteral.new(integer_part: str),
      :NUMBER
    )
  end

  def enum(sym)
    Graphlyte::Syntax::Value.new(sym, :ENUM)
  end
end
