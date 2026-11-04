# frozen_string_literal: true

RSpec.describe YardInlineRbs::PositionalParamType do
  let(:param) {described_class.new(type: 'String', name: 'title', description: 'The title.')}

  describe '#initialize' do
    it 'keeps the type, name and description' do
      expect([param.type, param.name, param.description]).to eq(['String', 'title', 'The title.'])
    end

    it 'has no name and no description by default' do
      param = described_class.new(type: 'String')
      expect([param.name, param.description]).to eq([nil, nil])
    end
  end
end
