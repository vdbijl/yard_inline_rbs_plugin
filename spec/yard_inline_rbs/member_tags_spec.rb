# frozen_string_literal: true

RSpec.describe YardInlineRbs::MemberTags do
  def method_type(text)
    RBS::Parser.parse_method_type(text)
  end

  def tags_of(object)
    object.tags.map {|tag| [tag.tag_name, tag.name, tag.types]}
  end

  let(:object) {YARD::Registry.at('#add')}
  let(:member_tags) {described_class.new(object)}

  before {YARD.parse_string('def add(item); end')}

  describe '#initialize' do
    it 'does not change the tags yet' do
      member_tags
      expect(tags_of(object)).to eq([])
    end
  end

  describe '#method_types' do
    context 'with one signature' do
      before {member_tags.method_types([method_type('(String) -> bool')])}

      it 'adds the parameter and return tags' do
        expect(tags_of(object)).to eq([['param', 'item', ['String']], ['return', nil, ['Boolean']]])
      end
    end

    context 'with several signatures' do
      before do
        member_tags.method_types([method_type('(String) -> bool'), method_type('(Integer) -> nil')])
      end

      it 'adds an @overload tag for each' do
        expect(object.tags(:overload).map(&:signature)).to eq(['add(arg0)', 'add(arg0)'])
      end
    end

    context 'with several signatures and other tags that are already there' do
      before do
        object.docstring.add_tag(YARD::Tags::Tag.new('return', 'The sum.', ['Integer']))
        member_tags.method_types([method_type('(String) -> bool'), method_type('(Integer) -> nil')])
      end

      it 'adds an @overload tag for each' do
        expect(object.tags(:overload).size).to eq(2)
      end
    end

    context 'with several signatures and an @overload tag that is already there' do
      before do
        object.docstring.add_tag(YARD::Tags::OverloadTag.new(:overload,
                                                             "add(item)\n  @return [nil]"))
        member_tags.method_types([method_type('(String) -> bool'), method_type('(Integer) -> nil')])
      end

      it 'keeps the existing @overload tag' do
        expect(object.tags(:overload).size).to eq(1)
      end
    end
  end

  describe '#duplicate_annotations' do
    context 'when an inline annotation typed what the declaration types' do
      before do
        object.docstring.add_tag(YARD::Tags::Tag.new('return', '', ['Integer']))
        YardInlineRbs::InlineTypes.record(object, ['the return type'], 'lib/shop.rb:3')
        member_tags.type(RBS::Parser.parse_type('String'))
      end

      it 'returns it' do
        expect(member_tags.duplicate_annotations).to eq(['the return type'])
      end
    end

    context 'when a YARD tag typed what the declaration types' do
      before do
        object.docstring.add_tag(YARD::Tags::Tag.new('return', '', ['Integer']))
        member_tags.type(RBS::Parser.parse_type('String'))
      end

      it 'returns nothing' do
        expect(member_tags.duplicate_annotations).to eq([])
      end
    end
  end

  describe '#type' do
    before {member_tags.type(RBS::Parser.parse_type('Array[String]'))}

    it 'adds a return tag' do
      expect(tags_of(object)).to eq([['return', nil, ['Array<String>']]])
    end
  end
end
