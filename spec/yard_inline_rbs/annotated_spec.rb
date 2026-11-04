# frozen_string_literal: true

RSpec.describe YardInlineRbs::Annotated do
  describe '.parameter' do
    it 'returns how the warnings name the parameter' do
      expect(described_class.parameter('count')).to eq("parameter 'count'")
    end
  end
end
