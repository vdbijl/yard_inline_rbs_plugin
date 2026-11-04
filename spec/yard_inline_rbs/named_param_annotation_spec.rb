# frozen_string_literal: true

RSpec.describe YardInlineRbs::NamedParamAnnotation do
  let(:annotation) {described_class.new(type: 'Integer', description: 'The count.')}

  describe '#initialize' do
    it 'keeps the type and description' do
      expect([annotation.type, annotation.description]).to eq(['Integer', 'The count.'])
    end

    it 'has no keyword rest by default' do
      expect(annotation.rest).to be(false)
    end

    it 'keeps that it is a keyword rest' do
      expect(described_class.new(type: 'Integer', rest: true).rest).to be(true)
    end
  end
end
