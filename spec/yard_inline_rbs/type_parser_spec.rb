# frozen_string_literal: true

RSpec.describe YardInlineRbs::TypeParser do
  let(:parse_errors) {[]}
  let(:types) {described_class.new(parse_errors)}

  describe '#initialize' do
    it 'does not change the list of parse errors' do
      described_class.new(parse_errors)
      expect(parse_errors).to eq([])
    end
  end

  describe '#type' do
    context 'with a valid type' do
      it 'returns the YARD type' do
        expect(types.type('bool')).to eq('Boolean')
      end
    end

    context 'with an invalid type' do
      before {types.type('BadType!!!')}

      it 'records the text as a parse error' do
        expect(parse_errors).to eq(['BadType!!!'])
      end
    end

    context 'with text after the type' do
      before {types.type('String name')}

      it 'records the text as a parse error' do
        expect(parse_errors).to eq(['String name'])
      end
    end

    # RBS returns nil for an empty type instead of raising.
    context 'with empty text' do
      before {types.type('')}

      it 'records the text as a parse error' do
        expect(parse_errors).to eq([''])
      end
    end
  end

  describe '#method_type?' do
    it 'returns true for a method type' do
      expect([types.method_type?('(Integer) -> String'), types.method_type?('[T] (T) -> T')])
        .to eq([true, true])
    end

    it 'returns true for a method type without parameter list' do
      expect(['{ () -> void } -> void', '-> Integer', '[T] { (T) -> void } -> T'].map do |text|
        types.method_type?(text)
      end)
        .to eq([true, true, true])
    end

    it 'returns false for a record type that contains a proc type' do
      expect(types.method_type?('{ call: ^() -> void }')).to be(false)
    end

    it 'returns false for a tuple and a parenthesised type that contain a proc type' do
      expect(['[^() -> void, Integer]', '(^(Integer) -> String)'].map do |text|
        types.method_type?(text)
      end)
        .to eq([false, false])
    end

    it 'returns false for a proc type, a type that contains one, and a plain type' do
      expect(['^(Integer) -> String', 'Hash[Symbol, ^() -> void]', 'Integer'].map do |text|
        types.method_type?(text)
      end)
        .to eq([false, false, false])
    end
  end

  describe '#method_signature' do
    context 'with text after the method type' do
      before {types.method_signature('(Integer) -> String extra junk')}

      it 'records a parse error' do
        expect(parse_errors).to eq(['(Integer) -> String extra junk'])
      end
    end

    context 'with empty text' do
      before {types.method_signature('')}

      it 'records a parse error' do
        expect(parse_errors).to eq([''])
      end
    end

    context 'with a valid method type' do
      it 'returns the return type and the block annotation' do
        result = types.method_signature('(Integer x) { (String) -> void } -> bool')
        expect([result[:return_type], result[:block_annotation].yield_types])
          .to eq(['Boolean', ['String']])
      end
    end

    context 'with an invalid method type' do
      before {types.method_signature('(Integer x -> bool')}

      it 'records the text as a parse error' do
        expect(parse_errors).to eq(['(Integer x -> bool'])
      end
    end
  end

  describe '#signature_of' do
    context 'with an untyped block' do
      it 'returns a block annotation without yield types' do
        method_type = RBS::Parser.parse_method_type('() { (?) -> untyped } -> void')
        expect(types.signature_of(method_type)[:block_annotation].yield_types).to eq([])
      end
    end

    context 'with a method type' do
      it 'returns the parameters, the return type and the block' do
        method_type = RBS::Parser.parse_method_type('(Integer x) { (String) -> void } -> bool')
        signature = types.signature_of(method_type)
        expect([signature[:positional_types].map(&:name), signature[:return_type],
                signature[:block_annotation].yield_types]).to eq([['x'], 'Boolean', ['String']])
      end
    end

    context 'with an untyped function' do
      it 'returns only the return type' do
        signature = types.signature_of(RBS::Parser.parse_method_type('(?) -> untyped'))
        expect(signature).to eq(positional_types: [], named_types: {}, block_annotation: nil,
                                return_type: 'untyped')
      end
    end
  end

  describe '#block_annotation' do
    context 'with text after the block type' do
      before {types.block_annotation('(String) -> void extra junk')}

      it 'records a parse error' do
        expect(parse_errors).to eq(['(String) -> void extra junk'])
      end
    end

    context 'with an untyped block' do
      it 'returns a block that yields no types' do
        expect(types.block_annotation('(?) -> untyped'))
          .to have_attributes(yield_types: [], return_type: 'untyped')
      end
    end

    context 'with empty text' do
      before {types.block_annotation('')}

      it 'records a parse error' do
        expect(parse_errors).to eq([''])
      end
    end

    context 'with a method type' do
      it 'returns the yield and return types' do
        annotation = types.block_annotation('(String) -> void')
        expect(annotation).to have_attributes(yield_types: ['String'], return_type: 'void')
      end
    end

    context 'with a plain type such as Proc' do
      it 'returns a block that yields no types' do
        expect(types.block_annotation('Proc')).to have_attributes(yield_types: [], return_type: nil)
      end
    end

    context 'with something that is no type' do
      before {types.block_annotation('Proc!!!')}

      it 'records the text as a parse error' do
        expect(parse_errors).to eq(['Proc!!!'])
      end
    end
  end
end
