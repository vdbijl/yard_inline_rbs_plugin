# frozen_string_literal: true

RSpec.describe YardInlineRbs::ParseResult do
  subject(:result) {described_class.new}

  def named(type)
    YardInlineRbs::NamedParamAnnotation.new(type: type)
  end

  def positional(type)
    YardInlineRbs::PositionalParamType.new(type: type)
  end

  def block(*yield_types)
    YardInlineRbs::BlockAnnotation.new(yield_types: yield_types, return_type: nil)
  end

  def signature(return_type: 'void', positional_types: [], named_types: {}, block_annotation: nil)
    { return_type: return_type, positional_types: positional_types, named_types: named_types,
      block_annotation: block_annotation }
  end

  describe '#initialize' do
    context 'without arguments' do
      it 'starts without annotations' do
        expect([result.positional_param_types, result.named_param_types, result.return_type,
                result.parse_errors, result.unsupported_annotations]).to eq([[], {}, nil, [], []])
      end
    end

    context 'with a return type and a description' do
      it 'keeps them' do
        result = described_class.new(return_type: 'String', return_description: 'The name.')
        expect([result.return_type, result.return_description]).to eq(['String', 'The name.'])
      end
    end
  end

  describe '#empty?' do
    it 'returns true without types' do
      expect(result.empty?).to be(true)
    end

    it 'returns false with a parameter, a return type or a block' do
      results = Array.new(3) {described_class.new}
      results[0].add_named_param('count', named('Integer'))
      results[1].add_return_type('String')
      results[2].add_block(block('Integer'))
      expect(results.map(&:empty?)).to eq([false, false, false])
    end

    it 'returns false with positional parameters' do
      result.add_signature(signature(return_type: nil, positional_types: [positional('Integer')]))
      expect(result.empty?).to be(false)
    end
  end

  describe '#overloads' do
    it 'returns nothing without overloads' do
      expect(result.overloads).to eq([])
    end
  end

  describe '#add_signatures' do
    let(:first) {signature(return_type: 'String')}
    let(:second) {signature(return_type: 'Float')}

    context 'with no signatures' do
      before {result.add_signatures([])}

      it 'adds nothing' do
        expect(result.empty?).to be(true)
      end
    end

    context 'with one signature' do
      before {result.add_signatures([first])}

      it 'adds its parts, and no overloads' do
        expect([result.return_type, result.overloads]).to eq(['String', []])
      end
    end

    context 'with several signatures' do
      before {result.add_signatures([first, second])}

      it 'adds them as overloads, and no parts' do
        expect([result.return_type, result.overloads]).to eq([nil, [first, second]])
      end
    end
  end

  describe '#add_overloads' do
    let(:first) {signature(return_type: 'String')}
    let(:second) {signature(return_type: 'Float')}

    context 'with two signatures' do
      before {result.add_overloads([first, second])}

      it 'keeps both, and no parameters of its own' do
        expect([result.overloads, result.positional_param_types, result.return_type])
          .to eq([[first, second], [], nil])
      end

      it 'makes the result not empty' do
        expect(result.empty?).to be(false)
      end
    end

    context 'with a signature before them' do
      before do
        result.add_signature(first)
        result.add_overloads([first, second])
      end

      it 'keeps the signature and records the duplicate once' do
        expect([result.overloads, result.return_type, result.duplicate_annotations])
          .to eq([[], 'String', ['the signature']])
      end
    end

    context 'with a signature after them' do
      before do
        result.add_overloads([first, second])
        result.add_signature(first)
      end

      it 'keeps the overloads and records the duplicate once' do
        expect([result.overloads, result.return_type, result.duplicate_annotations])
          .to eq([[first, second], nil, ['the signature']])
      end
    end

    context 'with a second set of overloads' do
      before do
        result.add_overloads([first, second])
        result.add_overloads([second, first])
      end

      it 'keeps the first overloads and records the duplicate once' do
        expect([result.overloads, result.duplicate_annotations])
          .to eq([[first, second], ['the signature']])
      end
    end
  end

  describe '#add_duplicate' do
    before {result.add_duplicate('the block')}

    it 'records what was typed again' do
      expect(result.duplicate_annotations).to eq(['the block'])
    end
  end

  describe '#add_return_type' do
    context 'with a type and a description' do
      before {result.add_return_type('String', 'The name.')}

      it 'keeps them' do
        expect([result.return_type, result.return_description, result.duplicate_annotations])
          .to eq(['String', 'The name.', []])
      end
    end

    context 'with a second type' do
      before do
        result.add_return_type('String', 'The name.')
        result.add_return_type('Integer', 'The count.')
      end

      it 'keeps the first and records the duplicate' do
        expect([result.return_type, result.return_description, result.duplicate_annotations])
          .to eq(['String', 'The name.', ['the return type']])
      end
    end

    # An invalid type is a parse error, which is reported on its own.
    context 'with a valid type, and then one that could not be parsed' do
      before do
        result.add_return_type('Integer')
        result.add_return_type(nil)
      end

      it 'keeps the valid type and records no duplicate' do
        expect([result.return_type, result.duplicate_annotations]).to eq(['Integer', []])
      end
    end

    context 'with a type that could not be parsed, and then a valid one' do
      before do
        result.add_return_type(nil)
        result.add_return_type('Integer')
      end

      it 'keeps the valid type' do
        expect([result.return_type, result.duplicate_annotations]).to eq(['Integer', []])
      end
    end
  end

  describe '#add_named_param' do
    context 'with two parameters' do
      before do
        result.add_named_param('count', named('Integer'))
        result.add_named_param('name', named('String'))
      end

      it 'keeps both' do
        expect(result.named_param_types.transform_values(&:type))
          .to eq('count' => 'Integer', 'name' => 'String')
      end
    end

    context 'with the same parameter twice' do
      before do
        result.add_named_param('count', named('Integer'))
        result.add_named_param('count', named('Float'))
      end

      it 'keeps the first and records the duplicate' do
        expect([result.named_param_types['count'].type, result.duplicate_annotations])
          .to eq(['Integer', ["parameter 'count'"]])
      end
    end

    context 'with a type that could not be parsed, and then a valid one' do
      before do
        result.add_named_param('count', named(nil))
        result.add_named_param('count', named('Float'))
      end

      it 'keeps the valid type' do
        expect([result.named_param_types['count'].type, result.duplicate_annotations])
          .to eq(['Float', []])
      end
    end
  end

  describe '#add_block' do
    # A block annotation that could not be parsed is nil; the parse error is reported on its own.
    context 'with a block and then nil' do
      before do
        result.add_block(block('Integer'))
        result.add_block(nil)
      end

      it 'keeps the block and records no duplicate' do
        expect([result.block_annotation.yield_types, result.duplicate_annotations])
          .to eq([['Integer'], []])
      end
    end

    context 'with a second block' do
      before do
        result.add_block(block('Integer'))
        result.add_block(block('String'))
      end

      it 'keeps the first and records the duplicate' do
        expect([result.block_annotation.yield_types, result.duplicate_annotations])
          .to eq([['Integer'], ['the block']])
      end
    end
  end

  describe '#add_signature' do
    context 'with a signature' do
      before do
        result.add_signature(signature(return_type: 'String',
                                       positional_types: [positional('Integer')],
                                       named_types: { 'label' => named('Symbol') },
                                       block_annotation: block('Float')))
      end

      it 'adds its parameters, return type and block' do
        expect([result.positional_param_types.map(&:type),
                result.named_param_types.transform_values(&:type), result.return_type,
                result.block_annotation.yield_types])
          .to eq([['Integer'], { 'label' => 'Symbol' }, 'String', ['Float']])
      end
    end

    context 'with a second signature' do
      before do
        result.add_signature(signature(return_type: 'String',
                                       positional_types: [positional('Integer')]))
        result.add_signature(signature(return_type: 'Float',
                                       positional_types: [positional('Float')]))
      end

      it 'keeps the first and records the duplicate once' do
        expect([result.positional_param_types.map(&:type), result.return_type,
                result.duplicate_annotations])
          .to eq([['Integer'], 'String', ['the signature']])
      end
    end

    context 'with a return type and a keyword parameter before it' do
      before do
        result.add_return_type('Integer')
        result.add_named_param('label', named('Symbol'))
        result.add_signature(signature(return_type: 'String',
                                       named_types: { 'label' => named('String'),
                                                      'flag' => named('Boolean') }))
      end

      it 'keeps them, adds the other keywords and records the duplicates' do
        expect([result.return_type, result.named_param_types.transform_values(&:type),
                result.duplicate_annotations])
          .to eq(['Integer', { 'label' => 'Symbol', 'flag' => 'Boolean' },
                  ["parameter 'label'", 'the return type']])
      end
    end

    context 'with a block before it' do
      before do
        result.add_block(block('Integer'))
        result.add_signature(signature(block_annotation: block('String')))
      end

      it 'keeps the block and records the duplicate' do
        expect([result.block_annotation.yield_types, result.duplicate_annotations])
          .to eq([['Integer'], ['the block']])
      end
    end
  end
end
