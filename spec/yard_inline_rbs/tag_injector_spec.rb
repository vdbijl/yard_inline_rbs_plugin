# frozen_string_literal: true

RSpec.describe YardInlineRbs::TagInjector do
  def make_object(name: :test_method, source: '', parameters: [], docstring: '')
    YARD::CodeObjects::MethodObject.new(:root, name).tap do |object|
      object.source = source
      object.parameters = parameters
      object.docstring = docstring
    end
  end

  before {YARD::Registry.clear}

  # The options are those of make_object.
  def make_parser(rbs_tags: [], description: '', **object_options)
    object = make_object(**object_options)
    parser = instance_double(YARD::DocstringParser, object: object, handler: nil, text: description)
    tags = rbs_tags.map {|text| YARD::Tags::Tag.new('rbs', text)}
    allow(parser).to receive(:tags).and_return(tags)
    allow(parser).to receive(:tags=) {|new_tags| tags.replace(new_tags)}
    allow(parser).to receive(:text=) {|new_text|
      allow(parser).to receive(:text).and_return(new_text)
    }
    parser
  end

  describe '#inject' do
    context 'with more annotated parameters than the method has' do
      let(:parser) do
        make_parser(rbs_tags: ['(Integer, String) -> bool'], parameters: [['x', nil]])
      end

      before {described_class.new(parser).inject}

      it 'injects @param tags only for the parameters of the method' do
        param_tags = parser.tags.select {|tag| tag.tag_name == 'param'}
        expect(param_tags.map {|tag| [tag.name, tag.types]}).to eq([['x', ['Integer']]])
      end
    end

    context 'when object is nil' do
      it 'does nothing' do
        parser = instance_double(YARD::DocstringParser, object: nil)
        expect {described_class.new(parser).inject}.not_to raise_error
      end
    end

    context 'with a full method signature @rbs tag' do
      let(:parser) do
        make_parser(
          rbs_tags: ['(Integer, String) -> bool'],
          parameters: [['x', nil], ['y', nil]]
        )
      end

      before {described_class.new(parser).inject}

      it 'injects @param tags for each positional' do
        param_tags = parser.tags.select {|tag| tag.tag_name == 'param'}
        expect(param_tags.map {|tag| [tag.name, tag.types]})
          .to eq([['x', ['Integer']], ['y', ['String']]])
      end

      it 'injects a @return tag' do
        return_tag = parser.tags.find {|tag| tag.tag_name == 'return'}
        expect(return_tag.types).to eq(['Boolean'])
      end

      it 'removes the @rbs tag' do
        expect(parser.tags.none? {|tag| tag.tag_name == 'rbs'}).to be(true)
      end
    end

    context 'with individual @rbs param annotations' do
      let(:parser) do
        make_parser(rbs_tags: ['name: String', 'return: Integer'])
      end

      before {described_class.new(parser).inject}

      it 'injects a @param tag for name' do
        param_tag = parser.tags.find {|tag| tag.tag_name == 'param' && tag.name == 'name'}
        expect(param_tag.types).to eq(['String'])
      end

      it 'injects a @return tag' do
        return_tag = parser.tags.find {|tag| tag.tag_name == 'return'}
        expect(return_tag.types).to eq(['Integer'])
      end
    end

    context 'when RBS overrides an existing YARD @param tag' do
      let(:parser) do
        object = make_object(parameters: [['x', nil]])
        parser = instance_double(YARD::DocstringParser, object: object, handler: nil, text: '')
        existing_param = YARD::Tags::Tag.new('param', 'description', ['String'], 'x')
        rbs_tag = YARD::Tags::Tag.new('rbs', '(Integer) -> void')
        tags = [existing_param, rbs_tag]
        allow(parser).to receive(:tags).and_return(tags)
        allow(parser).to receive(:tags=) {|new_tags| tags.replace(new_tags)}
        allow(parser).to receive(:text=)
        parser
      end

      before {described_class.new(parser).inject}

      it 'replaces the YARD @param type with the RBS type' do
        param_tag = parser.tags.find {|tag| tag.tag_name == 'param' && tag.name == 'x'}
        expect(param_tag.types).to eq(['Integer'])
      end
    end

    context 'when RBS overrides an existing YARD @return tag' do
      let(:parser) do
        object = make_object(name: :test_method, source: '', parameters: [])
        parser = instance_double(YARD::DocstringParser, object: object, handler: nil, text: '')
        existing_return = YARD::Tags::Tag.new('return', 'old description', ['String'])
        rbs_tag = YARD::Tags::Tag.new('rbs', 'return: Integer')
        tags = [existing_return, rbs_tag]
        allow(parser).to receive(:tags).and_return(tags)
        allow(parser).to receive(:tags=) {|new_tags| tags.replace(new_tags)}
        allow(parser).to receive(:text=)
        parser
      end

      before {described_class.new(parser).inject}

      it 'replaces the YARD @return type with the RBS type' do
        return_tags = parser.tags.select {|tag| tag.tag_name == 'return'}
        expect(return_tags.map(&:types)).to eq([['Integer']])
      end
    end

    context 'with a #: inline type in the description' do
      let(:parser) do
        object = make_object(name: :test_method, source: '', parameters: [])
        parser = instance_double(YARD::DocstringParser, object: object, handler: nil,
                                                        text: ": String\nSome description.")
        tags = []
        allow(parser).to receive(:tags).and_return(tags)
        allow(parser).to receive(:tags=) {|new_tags| tags.replace(new_tags)}
        allow(parser).to receive(:text=) {|new_text|
          allow(parser).to receive(:text).and_return(new_text)
        }
        parser
      end

      before {described_class.new(parser).inject}

      it 'injects a @return tag' do
        expect(parser.tags.find {|tag| tag.tag_name == 'return'}.types).to eq(['String'])
      end

      it 'strips the #: line from the description' do
        expect(parser.text).to eq('Some description.')
      end
    end

    context 'with no RBS annotations' do
      let(:parser) do
        make_parser(description: 'Just a description.')
      end

      it 'does not modify the tags' do
        original_count = parser.tags.length
        described_class.new(parser).inject
        expect(parser.tags.length).to eq(original_count)
      end
    end

    context 'with only annotations, on an object that has a description' do
      let(:parser) do
        make_parser(description: ': String', docstring: 'From the .rbs file.')
      end

      it 'keeps the description of the object' do
        described_class.new(parser).inject
        expect(parser.text).to eq('From the .rbs file.')
      end
    end

    context 'with annotations and a description, on an object that has a description' do
      let(:parser) do
        make_parser(description: "The Ruby text.\n: String", docstring: 'From the .rbs file.')
      end

      it 'keeps the new description' do
        described_class.new(parser).inject
        expect(parser.text).to eq('The Ruby text.')
      end
    end

    context 'with only @rbs tags, on an object that has a description' do
      let(:parser) do
        make_parser(rbs_tags: ['return: String'], docstring: 'From the .rbs file.')
      end

      it 'keeps the description of the object' do
        described_class.new(parser).inject
        expect(parser.text).to eq('From the .rbs file.')
      end
    end

    context 'with an indented code example in the description' do
      let(:parser) {make_parser(description: "Example:\n\n    shop.add(1)\n")}

      it 'keeps the description' do
        described_class.new(parser).inject
        expect(parser.text).to eq("Example:\n\n    shop.add(1)\n")
      end
    end

    context 'with a #: signature over three lines' do
      let(:parser) do
        make_parser(description: ": (Integer count,\n  String name)\n  -> String",
                    parameters: [['count', nil], ['name', nil]])
      end

      before {described_class.new(parser).inject}

      it 'injects the types of the whole signature' do
        expect(parser.tags.map {|tag| [tag.tag_name, tag.name, tag.types]})
          .to eq([['param', 'count', ['Integer']], ['param', 'name', ['String']],
                  ['return', nil, ['String']]])
      end
    end

    context 'with two #: lines, of which the second continues on the next line' do
      let(:parser) {make_parser(description: ": Integer\n: (Integer)\n  -> String")}

      before {described_class.new(parser).inject}

      it 'joins the continuation to the second' do
        expect(parser.tags.map {|tag| [tag.tag_name, tag.name, tag.types]})
          .to eq([['param', 'arg0', ['Integer']], ['return', nil, ['Integer']]])
      end
    end

    context 'with an empty #: line above the description' do
      let(:parser) {make_parser(description: ":\nThe name.")}

      before {allow(YARD::Logger.instance).to receive(:warn)}

      it 'removes the line from the description' do
        described_class.new(parser).inject
        expect(parser.text).to eq('The name.')
      end
    end

    context 'with the handler that parses the docstring' do
      let(:parser) do
        object = make_object
        statement = instance_double(YARD::Parser::Ruby::AstNode, line: 7, comments_range: 6..6)
        handler = instance_double(YARD::Handlers::Ruby::MethodHandler,
                                  parser: instance_double(YARD::Handlers::Processor,
                                                          file: 'lib/shop.rb'),
                                  statement: statement)
        rbs_tag = YARD::Tags::Tag.new('rbs', 'Array[')
        parser = instance_double(YARD::DocstringParser, object: object, handler: handler, text: '',
                                                        tags: [rbs_tag])
        allow(parser).to receive_messages('tags=': nil, 'text=': nil)
        parser
      end

      it 'warns with the location of its statement' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(%r{\[yard-inline-rbs\] lib/shop\.rb:7: could not parse RBS type 'Array\['})
        described_class.new(parser).inject
      end
    end

    context 'without annotations or description, on an object that has a description' do
      let(:parser) do
        make_parser(description: '', docstring: 'From the .rbs file.')
      end

      it 'leaves the empty description, as YARD does' do
        expect(parser).not_to receive(:text=)
        described_class.new(parser).inject
      end
    end
  end

  describe '#initialize' do
    it 'does not touch the parser until #inject is called' do
      parser = instance_double(YARD::DocstringParser)
      expect {described_class.new(parser)}.not_to raise_error
    end
  end
end
