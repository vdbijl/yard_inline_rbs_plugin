# frozen_string_literal: true

RSpec.describe YardInlineRbs::InlineTypes do
  let(:object) {YARD::CodeObjects::MethodObject.new(:root, :add)}

  describe '.record' do
    context 'with a second record' do
      before do
        described_class.record(object, ["parameter 'item'"], 'lib/shop.rb:2')
        described_class.record(object, ['the return type'], 'lib/shop.rb:7')
      end

      it 'replaces the first, like YARD replaces the docstring' do
        expect([described_class.typed?(object, "parameter 'item'"),
                described_class.typed?(object, 'the return type'),
                described_class.location(object)]).to eq([false, true, 'lib/shop.rb:7'])
      end
    end

    context 'with nothing typed, for an object without a record' do
      before {described_class.record(object, [], 'lib/shop.rb:2')}

      it 'stores nothing' do
        expect(described_class.location(object)).to be_nil
      end
    end
  end

  describe '.typed?' do
    context 'without a record' do
      it 'returns false' do
        expect(described_class.typed?(object, 'the return type')).to be(false)
      end
    end
  end

  describe '.any?' do
    context 'with a record of nothing' do
      before {described_class.record(object, [], 'lib/shop.rb:2')}

      it 'returns false' do
        expect(described_class.any?(object)).to be(false)
      end
    end

    context 'with a record of a type' do
      before {described_class.record(object, ['the block'], 'lib/shop.rb:2')}

      it 'returns true' do
        expect(described_class.any?(object)).to be(true)
      end
    end
  end

  describe '.location' do
    context 'without a record' do
      it 'returns nil' do
        expect(described_class.location(object)).to be_nil
      end
    end
  end
end
