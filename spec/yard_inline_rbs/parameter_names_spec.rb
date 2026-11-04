# frozen_string_literal: true

RSpec.describe YardInlineRbs::ParameterNames do
  def method_object(parameters)
    YARD::CodeObjects::MethodObject.new(:root, :greet).tap do |method|
      method.parameters = parameters
    end
  end

  before {YARD::Registry.clear}

  let(:names) do
    described_class.new(
      method_object([['x', nil], ['*rest', nil], ['name:', nil], ['**opts', nil], ['&block', nil]])
    )
  end

  describe '#initialize' do
    it 'accepts an object without parameters, such as a constant' do
      object = YARD::CodeObjects::ConstantObject.new(:root, :LIMIT)
      expect(described_class.new(object).positional).to eq([])
    end
  end

  describe '.placeholder' do
    it 'names an unnamed parameter by its position' do
      expect(described_class.placeholder(2)).to eq('arg2')
    end
  end

  describe '#empty?' do
    it 'returns true for an object without parameters' do
      expect(described_class.new(method_object([])).empty?).to be(true)
    end

    it 'returns false for an object with parameters' do
      expect(names.empty?).to be(false)
    end
  end

  describe '#positional' do
    it 'returns the positional names in Ruby order, without the splat prefix' do
      expect(names.positional).to eq(%w[x rest])
    end
  end

  describe '#tag_order' do
    it 'returns all names as @param tags name them' do
      expect(names.tag_order).to eq(%w[x rest name opts block])
    end
  end

  describe '#resolve_splat' do
    context 'with the placeholder of an unnamed splat' do
      it 'returns the name of the splat parameter' do
        expect(names.resolve_splat('*')).to eq('rest')
      end
    end

    context 'with the placeholder of an unnamed keyword rest' do
      it 'returns the name of the keyword rest parameter' do
        expect(names.resolve_splat('**')).to eq('opts')
      end
    end

    context 'with a name that is no placeholder' do
      it 'returns the name' do
        expect(names.resolve_splat('x')).to eq('x')
      end
    end

    context 'with the placeholder of an unnamed splat and only a keyword rest parameter' do
      it 'keeps the placeholder' do
        keywords_only = described_class.new(method_object([['**opts', nil]]))
        expect(keywords_only.resolve_splat('*')).to eq('*')
      end
    end

    context 'with an anonymous splat parameter' do
      it 'keeps the placeholder' do
        anonymous = described_class.new(method_object([['*', nil]]))
        expect(anonymous.resolve_splat('*')).to eq('*')
      end
    end
  end
end
