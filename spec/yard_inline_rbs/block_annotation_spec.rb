# frozen_string_literal: true

RSpec.describe YardInlineRbs::BlockAnnotation do
  let(:annotation) {described_class.new(yield_types: ['String'], return_type: 'void')}

  describe '#initialize' do
    it 'keeps the yield and return types' do
      expect([annotation.yield_types, annotation.return_type]).to eq([['String'], 'void'])
    end
  end
end
