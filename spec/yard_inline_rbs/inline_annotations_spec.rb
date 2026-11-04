# frozen_string_literal: true

RSpec.describe YardInlineRbs::InlineAnnotations do
  let(:result) {YardInlineRbs::ParseResult.new}
  let(:inline) do
    described_class.new(YardInlineRbs::TypeParser.new(result.parse_errors), result)
  end

  describe '#initialize' do
    it 'does not change the result' do
      inline
      expect(result.return_type).to be_nil
    end
  end

  describe '#process_line' do
    context 'with a union that continues with a tuple on the next line' do
      before {inline.process_line(": Integer\n  | [Float, String]")}

      it 'sets the return type, without a parse error' do
        expect([result.return_type, result.parse_errors])
          .to eq(['Integer, Array(Float, String)', []])
      end
    end

    context 'with a tuple that contains a proc type' do
      before {inline.process_line(': [^() -> void, Integer]')}

      it 'sets the return type, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Array(Proc, Integer)', []])
      end
    end

    context 'with a generic type that contains a proc type' do
      before {inline.process_line(': Hash[Symbol, ^() -> void]')}

      it 'sets the return type, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Hash{Symbol => Proc}', []])
      end
    end

    context 'with a method type that continues on the next line' do
      before {inline.process_line(": (Integer count)\n  -> String\n")}

      it 'sets the return type, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['String', []])
      end
    end

    context 'with an overload on the next line, which Steep rejects' do
      before {inline.process_line(": (Integer count) -> String\n  | (Float count) -> Float\n")}

      it 'records a parse error and no types' do
        expect([result.return_type, result.parse_errors])
          .to eq([nil, ['(Integer count) -> String | (Float count) -> Float']])
      end
    end

    context 'with a union type that continues on the next line' do
      before {inline.process_line(": Integer\n  | Float\n")}

      it 'sets the return type, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Integer, Float', []])
      end
    end

    context 'with an invalid method type' do
      before {inline.process_line(': (Integer -> String')}

      it 'records a parse error' do
        expect(result.parse_errors).to eq(['(Integer -> String'])
      end
    end

    context 'when the parameters are already known' do
      before do
        symbol = YardInlineRbs::PositionalParamType.new(type: 'Symbol')
        result.add_signature(positional_types: [symbol], named_types: {}, return_type: 'Symbol',
                             block_annotation: nil)
        result.add_named_param('name', YardInlineRbs::NamedParamAnnotation.new(type: 'Symbol'))
        inline.process_line(': (Integer count, name: String) -> String')
      end

      it 'keeps the known parameters' do
        expect([result.positional_param_types.map(&:type),
                result.named_param_types['name'].type]).to eq([['Symbol'], 'Symbol'])
      end
    end

    context 'with keyword parameters' do
      before {inline.process_line(': (name: String, ?flag: bool) -> void')}

      it 'sets their types by name' do
        expect(result.named_param_types.transform_values(&:type))
          .to eq('name' => 'String', 'flag' => 'Boolean')
      end
    end

    context 'when the return type and the block are already known' do
      before do
        result.add_return_type('String')
        result.add_block(YardInlineRbs::BlockAnnotation.new(yield_types: ['Symbol'],
                                                            return_type: nil))
        inline.process_line(': () { (Integer) -> void } -> Integer')
      end

      it 'keeps them' do
        expect([result.return_type, result.block_annotation.yield_types])
          .to eq(['String', ['Symbol']])
      end
    end

    context 'with an indented line' do
      before {inline.process_line("  : Integer\n")}

      it 'sets the return type' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a plain type' do
      before {inline.process_line(": Integer\n")}

      it 'sets the return type' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a method type' do
      before {inline.process_line(': (Integer count) -> String')}

      it 'sets the parameters and the return type' do
        expect([result.positional_param_types.map(&:name), result.return_type])
          .to eq([['count'], 'String'])
      end
    end

    context 'with a class-alias annotation' do
      before {inline.process_line(': class-alias')}

      it 'ignores the line' do
        expect(result.return_type).to be_nil
      end
    end

    context 'when the return type is already known' do
      before do
        result.add_return_type('String')
        inline.process_line(': Integer')
      end

      it 'keeps the known type' do
        expect(result.return_type).to eq('String')
      end
    end
  end

  describe '#process_trailing' do
    context 'with #: inside a string on the declaration line' do
      before {inline.process_trailing("def split(separator = '#:Foo')")}

      it 'finds no annotation' do
        expect([result.return_type, result.parse_errors]).to eq([nil, []])
      end
    end

    context 'with an invalid trailing method type comment' do
      before {inline.process_trailing('def count #: () -> ')}

      it 'records a parse error' do
        expect(result.parse_errors).to eq(['() ->'])
      end
    end

    context 'with a trailing type comment' do
      before {inline.process_trailing('attr_reader :count #: Integer')}

      it 'sets the return type' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a trailing method type comment' do
      before {inline.process_trailing('def count #: () -> Integer')}

      it 'sets the return type' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a trailing method type comment when the return type is already known' do
      before do
        result.add_return_type('String')
        inline.process_trailing('def count #: () -> Integer')
      end

      it 'keeps the known type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'without a trailing comment' do
      before {inline.process_trailing('attr_reader :count')}

      it 'sets nothing' do
        expect(result.return_type).to be_nil
      end
    end
  end
end
