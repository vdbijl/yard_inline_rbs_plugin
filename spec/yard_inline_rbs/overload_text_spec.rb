# frozen_string_literal: true

RSpec.describe YardInlineRbs::OverloadText do
  let(:signature) do
    YardInlineRbs::TypeParser.new([])
                             .method_signature('(String name, Integer, ?label: Symbol) -> bool')
  end

  describe '#initialize' do
    it 'accepts the name of the method and a signature' do
      expect {described_class.new(:add, signature)}.not_to raise_error
    end
  end

  describe '#to_s' do
    context 'with an unnamed keyword rest' do
      it 'calls and documents it as options' do
        signature = YardInlineRbs::TypeParser.new([]).method_signature('(**Integer) -> bool')
        expect(described_class.new(:add, signature).to_s).to eq(<<~TEXT.chomp)
          add(**options)
            @param options [Integer]
            @return [Boolean]
        TEXT
      end
    end

    context 'with a named keyword rest next to a keyword' do
      it 'calls the keyword rest with ** and the keyword with a colon' do
        method_type = '(name: String, **Integer opts) -> bool'
        signature = YardInlineRbs::TypeParser.new([]).method_signature(method_type)
        expect(described_class.new(:add, signature).to_s).to eq(<<~TEXT.chomp)
          add(name:, **opts)
            @param name [String]
            @param opts [Integer]
            @return [Boolean]
        TEXT
      end
    end

    context 'with a block' do
      it 'documents what the block yields and returns' do
        method_type = '(String) { (Integer, Symbol) -> void } -> bool'
        signature = YardInlineRbs::TypeParser.new([]).method_signature(method_type)
        expect(described_class.new(:each, signature).to_s).to eq(<<~TEXT.chomp)
          each(arg0)
            @param arg0 [String]
            @yield [Integer, Symbol]
            @yieldreturn [void]
            @return [Boolean]
        TEXT
      end
    end

    it 'returns the call and the nested tags, in the format YARD parses' do
      expect(described_class.new(:add, signature).to_s).to eq(<<~TEXT.chomp)
        add(name, arg1, label:)
          @param name [String]
          @param arg1 [Integer]
          @param label [Symbol]
          @return [Boolean]
      TEXT
    end
  end
end
