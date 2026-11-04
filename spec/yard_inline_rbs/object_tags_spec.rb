# frozen_string_literal: true

RSpec.describe YardInlineRbs::ObjectTags do
  let(:object) {YARD::Registry.at('#greet')}
  let(:object_tags) {described_class.new(object)}

  before do
    YARD.parse_string(<<~RUBY)
      # @param [String] name
      # @return [String]
      def greet(name); end
    RUBY
  end

  describe '#initialize' do
    it 'wraps the object' do
      expect(object_tags.object).to be(object)
    end
  end

  describe '#tags' do
    it 'returns the tags of the docstring of the object' do
      expect(object_tags.tags.map(&:tag_name)).to eq(%w[param return])
    end
  end

  describe '#tags=' do
    before do
      object_tags.tags = [YARD::Tags::Tag.new('return', '', ['Integer'])]
    end

    it 'replaces the tags of the docstring of the object' do
      expect(object.tags.map {|tag| [tag.tag_name, tag.types]}).to eq([['return', ['Integer']]])
    end
  end
end
