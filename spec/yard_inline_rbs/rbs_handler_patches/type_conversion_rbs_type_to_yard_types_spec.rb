# frozen_string_literal: true

RSpec.describe YardInlineRbs::RbsHandlerPatches::TypeConversion, '#rbs_type_to_yard_types' do
  let(:handler) {YARD::Handlers::RBS::MethodHandler}

  context 'with a valid RBS type' do
    it 'returns the type in YARD notation' do
      expect(handler.rbs_type_to_yard_types('Hash[Symbol, Array[String]?]'))
        .to eq(['Hash{Symbol => Array<String>, nil}'])
    end
  end

  context 'with text that is not an RBS type' do
    it 'returns what YARD makes of it' do
      expect(handler.rbs_type_to_yard_types('Array[')).to eq(['Array['])
    end
  end

  context 'with a valid type followed by text that is not part of it' do
    it 'returns what YARD makes of it, not the truncated type' do
      expect(handler.rbs_type_to_yard_types('Integer garbage')).to eq(['Integer garbage'])
    end
  end

  context 'with empty text' do
    it 'returns what YARD makes of it' do
      expect(handler.rbs_type_to_yard_types('')).to eq([])
    end
  end
end
