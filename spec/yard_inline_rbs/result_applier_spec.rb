# frozen_string_literal: true

RSpec.describe YardInlineRbs::ResultApplier do
  def parse_result(**overrides)
    YardInlineRbs::ParseResult.new(positional_param_types: [], named_param_types: {},
                                   return_type: nil, block_annotation: nil, **overrides)
  end

  def positional(type, name: nil)
    YardInlineRbs::PositionalParamType.new(type: type, name: name)
  end

  def tags_of(object)
    object.tags.map {|tag| [tag.tag_name, tag.name, tag.types]}
  end

  let(:object) {YARD::Registry.at('#greet')}
  let(:target) {YardInlineRbs::ObjectTags.new(object)}

  before do
    YARD.parse_string(<<~RUBY)
      # @param [Symbol] name
      # @return [Symbol]
      def greet(name, title = nil); end
    RUBY
  end

  describe '#initialize' do
    it 'does not change the tags yet' do
      described_class.new(target)
      expect(tags_of(object)).to eq([['param', 'name', ['Symbol']], ['return', nil, ['Symbol']]])
    end
  end

  describe '#typed' do
    context 'when #apply has not run' do
      it 'returns nothing' do
        expect(described_class.new(target).typed).to eq([])
      end
    end

    context 'when #apply has run' do
      let(:applier) {described_class.new(target)}

      before do
        block = YardInlineRbs::BlockAnnotation.new(yield_types: ['String'], return_type: nil)
        applier.apply(parse_result(positional_param_types: [positional('String')],
                                   return_type: 'Symbol', block_annotation: block))
      end

      it 'returns what it typed' do
        expect(applier.typed).to eq(["parameter 'name'", 'the return type', 'the block'])
      end
    end
  end

  describe '#apply' do
    let(:result) do
      parse_result(positional_param_types: [positional('String'), positional('Integer')],
                   return_type: 'String')
    end

    let(:overloaded) do
      signatures = [{ positional_types: [positional('String')], named_types: {},
                      return_type: 'String', block_annotation: nil },
                    { positional_types: [], named_types: {}, return_type: 'Symbol',
                      block_annotation: nil }]
      parse_result.tap {|result| result.add_overloads(signatures)}
    end

    context 'without keep_existing' do
      before {described_class.new(target).apply(result)}

      it 'replaces the existing types' do
        expect(tags_of(object))
          .to eq([['param', 'name', ['String']], ['param', 'title', ['Integer']],
                  ['return', nil, ['String']]])
      end
    end

    context 'with keep_existing' do
      before {described_class.new(target, keep_existing: true).apply(result)}

      it 'adds only the missing tags' do
        expect(tags_of(object))
          .to eq([['param', 'name', ['Symbol']], ['param', 'title', ['Integer']],
                  ['return', nil, ['Symbol']]])
      end
    end

    context 'with keep_existing and documented tags without types' do
      before do
        YARD.parse_string("# @param name The name.\n# @return The greeting.\ndef hello(name); end")
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#hello')),
                            keep_existing: true)
                       .apply(parse_result(positional_param_types: [positional('String')],
                                           return_type: 'Symbol'))
      end

      it 'adds the types and keeps the descriptions' do
        expect(YARD::Registry.at('#hello').tags.map {|tag| [tag.tag_name, tag.types, tag.text]})
          .to eq([['param', ['String'], 'The name.'], ['return', ['Symbol'], 'The greeting.']])
      end
    end

    context 'with keep_existing and a documented @yieldreturn without @yield' do
      before do
        YARD.parse_string("# @yieldreturn [Boolean] Whether to keep it.\ndef each; end")
        block = YardInlineRbs::BlockAnnotation.new(yield_types: ['String'], return_type: 'Integer')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#each')),
                            keep_existing: true)
                       .apply(parse_result(block_annotation: block))
      end

      it 'keeps the @yieldreturn and adds the @yield' do
        expect(YARD::Registry.at('#each').tags.map {|tag| [tag.tag_name, tag.types]})
          .to contain_exactly(['yieldreturn', ['Boolean']], ['yield', ['String']])
      end
    end

    context 'with keep_existing and a block that is already documented' do
      before do
        object.docstring.add_tag(YARD::Tags::Tag.new('yield', '', ['Symbol']))
        block = YardInlineRbs::BlockAnnotation.new(yield_types: ['String'], return_type: nil)
        described_class.new(target,
                            keep_existing: true).apply(parse_result(block_annotation: block))
      end

      it 'keeps the yield tag' do
        expect(object.tag(:yield).types).to eq(['Symbol'])
      end
    end

    context 'when the method has no Ruby parameters' do
      before do
        YARD.parse_string('class Shop; end')
        YARD::Registry.at('Shop').tap {|shop| YARD::CodeObjects::MethodObject.new(shop, :find)}
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('Shop#find')))
                       .apply(parse_result(positional_param_types: [positional('String')]))
      end

      it 'names the parameters arg0, arg1, ...' do
        expect(tags_of(YARD::Registry.at('Shop#find'))).to eq([['param', 'arg0', ['String']]])
      end
    end

    context 'with an operator method that ends in =' do
      before do
        YARD.parse_string('def ==(other); end')
        operator = YARD::Registry.at('#==')
        described_class.new(YardInlineRbs::ObjectTags.new(operator))
                       .apply(parse_result(return_type: 'Boolean'))
      end

      it 'tags the return type, not a parameter' do
        expect(tags_of(YARD::Registry.at('#=='))).to eq([['return', nil, ['Boolean']]])
      end
    end

    context 'with a writer method' do
      before do
        YARD.parse_string('def name=(value); end')
        writer = YARD::Registry.at('#name=')
        described_class.new(YardInlineRbs::ObjectTags.new(writer))
                       .apply(parse_result(return_type: 'String'))
      end

      it 'tags the parameter' do
        expect(tags_of(YARD::Registry.at('#name='))).to eq([['param', 'value', ['String']]])
      end
    end

    context 'with documented tags and an annotation without description' do
      before do
        YARD.parse_string(<<~RUBY)
          # @param [Symbol] name The name.
          # @return [Symbol] The greeting.
          def welcome(name); end
        RUBY
        annotated = parse_result(positional_param_types: [positional('String')],
                                 return_type: 'String')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#welcome'))).apply(annotated)
      end

      it 'replaces the types and keeps the descriptions' do
        expect(YARD::Registry.at('#welcome').tags.map {|tag| [tag.tag_name, tag.types, tag.text]})
          .to eq([['param', ['String'], 'The name.'], ['return', ['String'], 'The greeting.']])
      end
    end

    context 'with documented tags and an annotation with a description' do
      before do
        YARD.parse_string("# @param [Symbol] name The name.\ndef welcome(name); end")
        described = YardInlineRbs::PositionalParamType.new(type: 'String',
                                                           description: 'Who to greet.')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#welcome')))
                       .apply(parse_result(positional_param_types: [described]))
      end

      it 'takes the description of the annotation' do
        expect(YARD::Registry.at('#welcome').tag(:param).text).to eq('Who to greet.')
      end
    end

    context 'with a parameter annotation whose type is not valid' do
      before do
        invalid = YardInlineRbs::NamedParamAnnotation.new(type: nil)
        described_class.new(target).apply(parse_result(named_param_types: { 'name' => invalid }))
      end

      it 'keeps the existing tag of the parameter' do
        expect(tags_of(object)).to eq([['param', 'name', ['Symbol']], ['return', nil, ['Symbol']]])
      end
    end

    context 'with an indexed writer and a type for its value' do
      before do
        YARD.parse_string('def []=(key, value); end')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#[]=')))
                       .apply(parse_result(return_type: 'Integer'))
      end

      it 'tags the value, not the key' do
        expect(tags_of(YARD::Registry.at('#[]='))).to eq([['param', 'value', ['Integer']]])
      end
    end

    context 'with an indexed writer and a signature' do
      before do
        YARD.parse_string('def []=(key, value); end')
        types = [positional('Symbol'), positional('Integer')]
        signature = parse_result(positional_param_types: types, return_type: 'Integer')
        writer = YardInlineRbs::ObjectTags.new(YARD::Registry.at('#[]='))
        described_class.new(writer).apply(signature)
      end

      it 'keeps the type of the key' do
        expect(tags_of(YARD::Registry.at('#[]='))).to eq([['param', 'key', ['Symbol']],
                                                          ['param', 'value', ['Integer']]])
      end
    end

    context 'with a named and a positional annotation for the same parameter' do
      let(:annotated) do
        named = { 'name' => YardInlineRbs::NamedParamAnnotation.new(type: 'String') }
        parse_result(named_param_types: named,
                     positional_param_types: [positional('Integer'), positional('Float')])
      end

      before {described_class.new(target).apply(annotated)}

      it 'keeps the named type and records the duplicate' do
        expect([tags_of(object).first(2), annotated.duplicate_annotations])
          .to eq([[['param', 'name', ['String']], ['param', 'title', ['Float']]],
                  ["parameter 'name'"]])
      end
    end

    context 'with an indexed writer whose signature types the value twice' do
      let(:signature) do
        parse_result(positional_param_types: [positional('Symbol'), positional('Integer')],
                     return_type: 'Integer')
      end

      before do
        YARD.parse_string('def []=(key, value); end')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#[]='))).apply(signature)
      end

      it 'records no duplicate' do
        expect(signature.duplicate_annotations).to eq([])
      end
    end

    context 'with an indexed writer, a type for its key and a type for its value' do
      before do
        YARD.parse_string('def []=(key, value); end')
        key = { 'key' => YardInlineRbs::NamedParamAnnotation.new(type: 'Symbol') }
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#[]=')))
                       .apply(parse_result(named_param_types: key, return_type: 'Integer'))
      end

      it 'tags both parameters' do
        expect(tags_of(YARD::Registry.at('#[]='))).to eq([['param', 'key', ['Symbol']],
                                                          ['param', 'value', ['Integer']]])
      end
    end

    # RBS parameter names are documentation only: Steep does not check them against Ruby.
    context 'with an annotation that names the parameters differently from Ruby' do
      before do
        named = [positional('String', name: 'person'), positional('Integer', name: 'rank')]
        described_class.new(target).apply(parse_result(positional_param_types: named))
      end

      it 'uses the Ruby names' do
        expect(tags_of(object).filter_map {|tag| tag[1]}).to eq(%w[name title])
      end
    end

    context 'with an indexed writer with other parameter names' do
      before do
        YARD.parse_string('def []=(index, amount); end')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#[]=')))
                       .apply(parse_result(return_type: 'Integer'))
      end

      it 'tags the last parameter' do
        expect(tags_of(YARD::Registry.at('#[]='))).to eq([['param', 'amount', ['Integer']]])
      end
    end

    context 'with a writer without parameters' do
      before do
        writer = YARD::CodeObjects::MethodObject.new(:root, :count=)
        described_class.new(YardInlineRbs::ObjectTags.new(writer))
                       .apply(parse_result(return_type: 'Integer'))
      end

      it 'tags a parameter called value' do
        expect(tags_of(YARD::Registry.at('#count='))).to eq([['param', 'value', ['Integer']]])
      end
    end

    context 'with a writer without Ruby parameters and a signature that names its parameter' do
      before do
        writer = YARD::CodeObjects::MethodObject.new(:root, :level=)
        signature = parse_result(positional_param_types: [positional('Integer', name: 'new_level')],
                                 return_type: 'Integer')
        described_class.new(YardInlineRbs::ObjectTags.new(writer)).apply(signature)
      end

      it 'tags that parameter once, not also one called value' do
        expect(tags_of(YARD::Registry.at('#level='))).to eq([['param', 'new_level', ['Integer']]])
      end
    end

    context 'with a writer without Ruby parameters and a signature that does not name it' do
      before do
        writer = YARD::CodeObjects::MethodObject.new(:root, :level=)
        signature = parse_result(positional_param_types: [positional('Integer')],
                                 return_type: 'Integer')
        described_class.new(YardInlineRbs::ObjectTags.new(writer)).apply(signature)
      end

      it 'tags the parameter arg0 once' do
        expect(tags_of(YARD::Registry.at('#level='))).to eq([['param', 'arg0', ['Integer']]])
      end
    end

    context 'when the method has no Ruby parameters and the annotation names them' do
      before do
        finder = YARD::CodeObjects::MethodObject.new(:root, :find)
        described_class.new(YardInlineRbs::ObjectTags.new(finder))
                       .apply(parse_result(positional_param_types: [positional('String',
                                                                               name: 'query')]))
      end

      it 'uses the names of the annotation' do
        expect(tags_of(YARD::Registry.at('#find'))).to eq([['param', 'query', ['String']]])
      end
    end

    context 'with an @option tag for an annotated parameter' do
      before do
        YARD.parse_string("# @option options [String] :name The name.\ndef build(options); end")
        hash = YardInlineRbs::NamedParamAnnotation.new(type: 'Hash')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#build')))
                       .apply(parse_result(named_param_types: { 'options' => hash }))
      end

      # YARD adds the @param tag of an @option without one.
      it 'keeps the @option tag and the description of the @param tag' do
        expect(YARD::Registry.at('#build').tags.map {|tag| [tag.tag_name, tag.name, tag.text]})
          .to eq([['option', 'options', nil],
                  ['param', 'options', 'a customizable set of options']])
      end
    end

    context 'with another documented parameter and an annotation without description' do
      before do
        YARD.parse_string("# @param [Object] other The other.\ndef pair(count, other); end")
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#pair')))
                       .apply(parse_result(positional_param_types: [positional('Integer')]))
      end

      it 'does not take the description of the other parameter' do
        expect(YARD::Registry.at('#pair').tags.map {|tag| [tag.name, tag.text]})
          .to eq([['count', ''], ['other', 'The other.']])
      end
    end

    context 'with documented @yield and @yieldreturn tags and a block annotation' do
      before do
        YARD.parse_string(<<~RUBY)
          # @yield [Object] Each item.
          # @yieldreturn [Object] Whether to keep it.
          def each; end
        RUBY
        block = YardInlineRbs::BlockAnnotation.new(yield_types: ['String'], return_type: 'Boolean')
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#each')))
                       .apply(parse_result(block_annotation: block))
      end

      it 'replaces the types and keeps the descriptions' do
        expect(YARD::Registry.at('#each').tags.map {|tag| [tag.tag_name, tag.types, tag.text]})
          .to eq([['yield', ['String'], 'Each item.'],
                  ['yieldreturn', ['Boolean'], 'Whether to keep it.']])
      end
    end

    context 'with a block annotation and no documented block' do
      before do
        block = YardInlineRbs::BlockAnnotation.new(yield_types: ['String'], return_type: 'Boolean')
        described_class.new(target).apply(parse_result(block_annotation: block))
      end

      it 'adds @yield and @yieldreturn tags without description' do
        expect(object.tags.drop(2).map {|tag| [tag.tag_name, tag.types, tag.text]})
          .to eq([['yield', ['String'], ''], ['yieldreturn', ['Boolean'], '']])
      end
    end

    # Ruby's sort_by is not stable, so the order must not depend on it.
    context 'with many documented parameters that the method does not have' do
      let(:unknown_names) {(1..10).map {|number| "old#{number}"}}

      before do
        documented = unknown_names.map {|name| "# @param [Object] #{name}\n"}.join
        YARD.parse_string("#{documented}def go(count); end")
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#go')))
                       .apply(parse_result(positional_param_types: [positional('Integer')]))
      end

      it 'puts them after the parameters of the method, in their own order' do
        expect(YARD::Registry.at('#go').tags.map(&:name)).to eq(['count', *unknown_names])
      end
    end

    context 'with an annotated parameter that the method does not have' do
      before do
        extra = %w[A B C].map {|type| positional(type)}
        described_class.new(target).apply(parse_result(positional_param_types: extra))
      end

      it 'ignores the parameter' do
        expect(tags_of(object).filter_map {|tag| tag[1]}).to eq(%w[name title])
      end
    end

    context 'when it runs twice' do
      it 'returns only what the last run typed' do
        applier = described_class.new(target)
        applier.apply(result)
        applier.apply(parse_result(return_type: 'Integer'))
        expect(applier.typed).to eq(['the return type'])
      end
    end

    context 'with two existing tags of the same parameter and an annotation without description' do
      before do
        YARD.parse_string("# @param name First.\n# @param name Second.\ndef hi(name); end")
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#hi')))
                       .apply(parse_result(positional_param_types: [positional('String')]))
      end

      it 'keeps the description of the first tag' do
        expect(YARD::Registry.at('#hi').tags.map {|tag| [tag.types, tag.text]})
          .to eq([[['String'], 'First.']])
      end
    end

    context 'with overloads and without an @overload tag' do
      let(:applier) {described_class.new(target)}

      before {applier.apply(overloaded)}

      it 'adds an @overload tag for each signature' do
        expect(object.tags(:overload).map(&:signature)).to eq(['greet(arg0)', 'greet()'])
      end

      it 'records the signature as typed' do
        expect(applier.typed).to eq(['the signature'])
      end
    end

    context 'with overloads and an @overload tag that is already there' do
      let(:applier) do
        described_class.new(YardInlineRbs::ObjectTags.new(YARD::Registry.at('#hi')))
      end

      before do
        YARD.parse_string("# @overload hi(name)\n#   @return [nil]\ndef hi(name); end")
        applier.apply(overloaded)
      end

      it 'keeps the existing @overload tag and adds none' do
        expect(YARD::Registry.at('#hi').tags(:overload).map(&:signature)).to eq(['hi(name)'])
      end

      it 'records nothing as typed' do
        expect(applier.typed).to eq([])
      end
    end
  end
end
