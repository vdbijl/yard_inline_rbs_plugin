# frozen_string_literal: true

RSpec.describe YardInlineRbs do
  def parse(ruby_source)
    YARD::Registry.clear
    YARD.parse_string(ruby_source)
  end

  describe 'method with full @rbs signature' do
    before do
      parse(<<~RUBY)
        # Does something.
        # @rbs (Integer, String) -> bool
        def foo(count, name); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#foo')}

    it 'sets @param types from RBS' do
      param_types = method_object.tags(:param).to_h {|tag| [tag.name, tag.types]}
      expect(param_types).to eq('count' => ['Integer'], 'name' => ['String'])
    end

    it 'sets @return type from RBS' do
      expect(method_object.tag(:return).types).to eq(['Boolean'])
    end

    it 'strips the @rbs line from the description' do
      expect(method_object.docstring).to eq('Does something.')
    end
  end

  describe 'method with individual @rbs param/return annotations' do
    before do
      parse(<<~RUBY)
        # @rbs name: String
        # @rbs return: Integer
        def greet(name); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#greet')}

    it 'injects @param tag' do
      param_tag = method_object.tag(:param)
      expect([param_tag.name, param_tag.types]).to eq(['name', ['String']])
    end

    it 'injects @return tag' do
      expect(method_object.tag(:return).types).to eq(['Integer'])
    end
  end

  describe 'method with #: prefix annotation' do
    before do
      parse(<<~RUBY)
        #: (Integer) -> String
        def bar(x); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#bar')}

    it 'sets @param type from #: annotation' do
      expect(method_object.tag(:param).types).to eq(['Integer'])
    end

    it 'sets @return type from #: annotation' do
      expect(method_object.tag(:return).types).to eq(['String'])
    end
  end

  describe 'method with trailing #: annotation' do
    before do
      parse(<<~RUBY)
        def baz(x) #: (Integer) -> String
          x.to_s
        end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#baz')}

    it 'sets @return type from trailing #:' do
      expect(method_object.tag(:return).types).to eq(['String'])
    end
  end

  describe 'RBS overrides existing YARD @param and @return' do
    before do
      parse(<<~RUBY)
        # @param [String] count
        # @return [String]
        # @rbs (Integer) -> bool
        def qux(count); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#qux')}

    it 'replaces @param type with RBS type' do
      expect(method_object.tag(:param).types).to eq(['Integer'])
    end

    it 'replaces @return type with RBS type' do
      expect(method_object.tag(:return).types).to eq(['Boolean'])
    end
  end

  describe 'method with optional type parameter' do
    before do
      parse(<<~RUBY)
        # @rbs (String?) -> void
        def process(value); end
      RUBY
    end

    it "formats optional type as 'Type, nil'" do
      param_tag = YARD::Registry.at('#process').tag(:param)
      expect(param_tag.types).to eq(['String, nil'])
    end
  end

  describe 'attr_accessor with trailing #: annotation' do
    let(:source_file) {Tempfile.new(['switch_state', '.rb'])}

    before do
      source_file.write(<<~RUBY)
        class Widget
          # The current count.
          attr_accessor :count #: Integer

          # An optional label.
          attr_reader :label #: String?
        end
      RUBY
      source_file.flush
      YARD.parse(source_file.path)
    end

    after {source_file.close!}

    it 'injects @return type on the reader method' do
      reader = YARD::Registry.all(:method).find {|m| m.name == :count && !m.writer?}
      expect(reader.tag(:return).types).to eq(['Integer'])
    end

    it 'injects @param type on the writer method' do
      writer = YARD::Registry.all(:method).find {|m| m.name == :count=}
      expect(writer.tag(:param).types).to eq(['Integer'])
    end

    it 'handles optional type on attr_reader' do
      reader = YARD::Registry.all(:method).find {|m| m.name == :label}
      expect(reader.tag(:return).types).to eq(['String, nil'])
    end
  end

  describe '@rbs return annotation with -- description' do
    before do
      parse(<<~RUBY)
        # @rbs return: String -- The greeting message.
        def greet; end
      RUBY
    end

    it 'injects @return type' do
      expect(YARD::Registry.at('#greet').tag(:return).types).to eq(['String'])
    end

    it 'injects @return description' do
      expect(YARD::Registry.at('#greet').tag(:return).text).to eq('The greeting message.')
    end
  end

  describe '@rbs return annotation with -- description on continuation line' do
    before do
      parse(<<~RUBY)
        # @rbs return: String | Integer
        #   -- The combined result value.
        def compute; end
      RUBY
    end

    it 'injects @return type' do
      expect(YARD::Registry.at('#compute').tag(:return).types).to eq(['String, Integer'])
    end

    it 'injects @return description from continuation line' do
      expect(YARD::Registry.at('#compute').tag(:return).text).to eq('The combined result value.')
    end
  end

  describe 'a signature that continues on the next comment line' do
    def documentation(source)
      parse(source)
      object = YARD::Registry.at('#label')
      [object.docstring.to_s, object.tags.map {|tag| [tag.tag_name, tag.name, tag.types]}]
    end

    let(:label_documentation) do
      ['Doc.', [['param', 'count', ['Integer']], ['return', nil, ['String']]]]
    end

    it 'documents an @rbs signature' do
      expect(documentation(<<~RUBY)).to eq(label_documentation)
        # Doc.
        # @rbs (Integer count)
        #   -> String
        def label(count); end
      RUBY
    end

    it 'documents a #: signature and removes it from the description' do
      expect(documentation(<<~RUBY)).to eq(label_documentation)
        # Doc.
        #: (Integer count)
        #   -> String
        def label(count); end
      RUBY
    end

    it 'documents a parameter list over several lines' do
      expect(documentation(<<~RUBY)).to eq(label_documentation)
        # Doc.
        # @rbs (
        #   Integer count
        #   ) -> String
        def label(count); end
      RUBY
    end
  end

  describe 'an @rbs signature with overloads' do
    before do
      parse(<<~RUBY)
        # Doc.
        # @rbs (Integer count) -> String
        #    | (Float count) -> Float
        def label(count); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#label')}

    it 'documents an @overload tag for each signature' do
      expect(method_object.tags(:overload).map {|overload| overload.tags.map(&:types)})
        .to eq([[['Integer'], ['String']], [['Float'], ['Float']]])
    end

    it 'adds no @param or @return tag to the method itself' do
      expect(method_object.tags.map(&:tag_name)).to eq(%w[overload overload])
    end
  end

  describe 'a #: signature above a method with an @overload tag' do
    before do
      parse(<<~RUBY)
        # @overload label(count)
        #   @return [Symbol]
        #: (String count) -> String
        def label(count); end
      RUBY
    end

    it 'keeps the @overload tag and documents the signature on the method' do
      method_object = YARD::Registry.at('#label')
      expect(method_object.tags.map {|tag| [tag.tag_name, tag.types]})
        .to eq([['overload', nil], ['param', ['String']], ['return', ['String']]])
    end
  end

  describe 'attr_writer with trailing #: annotation' do
    it 'injects @param type on the writer method' do
      parse("class Widget\n  attr_writer :level #: Integer\nend")
      expect(YARD::Registry.at('Widget#level=').tag(:param).types).to eq(['Integer'])
    end
  end

  describe 'a class-level attribute with trailing #: annotation' do
    it 'injects @return type on the class method' do
      parse("class Widget\n  class << self\n    attr_reader :count #: Integer\n  end\nend")
      expect(YARD::Registry.at('Widget.count').tag(:return).types).to eq(['Integer'])
    end
  end

  describe 'an annotation in a file with Windows line endings' do
    it 'documents the types' do
      parse("# @rbs count: Integer\r\n# @rbs return: String\r\ndef label(count); end\r\n")
      method_object = YARD::Registry.at('#label')
      expect([method_object.tag(:param).types, method_object.tag(:return).types])
        .to eq([['Integer'], ['String']])
    end
  end

  describe 'a parameter with an intersection type' do
    it 'documents the parts joined by &' do
      parse("#: (Comparable & Enumerable[Integer] items) -> void\ndef sort(items); end")
      expect(YARD::Registry.at('#sort').tag(:param).types)
        .to eq(['Comparable & Enumerable<Integer>'])
    end
  end

  describe 'a parameter with a tuple type and a record type' do
    it 'documents YARD notation of the elements' do
      parse(<<~RUBY)
        #: ([Integer, String] pair, { name: String } options) -> void
        def add(pair, options); end
      RUBY
      expect(YARD::Registry.at('#add').tags(:param).map(&:types))
        .to eq([['Array(Integer, String)'], ['Hash{Symbol => String}']])
    end
  end

  # Steep accepts overloads in an @rbs signature, but not in a #: signature.
  describe 'a #: signature with an overload' do
    let(:source) do
      <<~RUBY
        # Doc.
        #: (Integer count) -> String
        #  | (Float count) -> Float
        def label(count); end
      RUBY
    end

    it 'logs a YARD warning' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with('[yard-inline-rbs] (stdin):4: could not parse RBS type '\
              "'(Integer count) -> String | (Float count) -> Float'")
      parse(source)
    end

    it 'removes the annotation from the description' do
      allow(YARD::Logger.instance).to receive(:warn)
      parse(source)
      expect(YARD::Registry.at('#label').docstring.to_s).to eq('Doc.')
    end
  end

  # docs/limitations.md: rbs reads these methods as instance methods, YARD does not.
  describe 'a method in class << self' do
    before do
      parse(<<~RUBY)
        class Shop
          class << self
            # @rbs (Integer count) -> Shop
            def build(count); end
          end
        end
      RUBY
    end

    it 'documents the types on the class method' do
      expect(YARD::Registry.at('Shop.build').tags.map {|tag| [tag.tag_name, tag.name, tag.types]})
        .to eq([['param', 'count', ['Integer']], ['return', nil, ['Shop']]])
    end
  end

  # docs/limitations.md: Steep rejects the rbs-inline syntax for Struct members.
  describe 'a Struct with #: member annotations' do
    let(:source_file) {Tempfile.new(['shop', '.rb'])}

    before do
      source_file.write("PendingStep = Struct.new(\n  :step,  #: String\n  :error  #: String?\n)\n")
      source_file.flush
    end

    after {source_file.close!}

    it 'logs no warning' do
      expect(YARD::Logger.instance).not_to receive(:warn)
      YARD.parse(source_file.path)
    end

    it 'ignores the member types' do
      YARD.parse(source_file.path)
      expect(YARD::Registry.at('PendingStep#step').tag(:return).types).to eq(['Object'])
    end
  end

  describe 'an empty @rbs annotation' do
    it 'logs a YARD warning' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with("[yard-inline-rbs] (stdin):3: could not parse RBS type ''")
      parse("# Doc.\n# @rbs\ndef label(count); end")
    end
  end

  describe 'an empty #: annotation' do
    it 'logs a YARD warning' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with("[yard-inline-rbs] (stdin):3: could not parse RBS type ''")
      parse("# Doc.\n#:\ndef label(count); end")
    end

    it 'removes it from the description' do
      allow(YARD::Logger.instance).to receive(:warn)
      parse("# Doc.\n#:\ndef label(count); end")
      expect(YARD::Registry.at('#label').docstring.to_s).to eq('Doc.')
    end
  end

  # Found on a real project: RBS allows a method type without parameter list.
  describe 'method signature with a block and without parameter list' do
    before do
      parse(<<~RUBY)
        # @rbs { (Integer) -> void } -> String
        def each_count(&block); end
      RUBY
    end

    it 'injects @return, @yield and @yieldreturn' do
      expect(YARD::Registry.at('#each_count').tags.map {|tag| [tag.tag_name, tag.types]})
        .to eq([['return', ['String']], ['yield', ['Integer']], ['yieldreturn', ['void']]])
    end
  end

  describe 'method with @rbs block annotation' do
    before do
      parse(<<~RUBY)
        # @rbs name: String
        # @rbs &block: (Integer) -> void
        # @rbs return: String
        def greet(name, &block); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#greet')}

    it 'injects @yield with the block param types' do
      expect(method_object.tag(:yield).types).to eq(['Integer'])
    end

    it 'injects @yieldreturn with the block return type' do
      expect(method_object.tag(:yieldreturn).types).to eq(['void'])
    end

    it 'still injects @param and @return' do
      expect([method_object.tag(:param).types, method_object.tag(:return).types])
        .to eq([['String'], ['String']])
    end
  end

  describe 'splat param annotation (*name: Type)' do
    before do
      parse(<<~RUBY)
        # @rbs *names: String
        # @rbs return: void
        def greet(*names); end
      RUBY
    end

    it 'injects @param for the splat parameter' do
      param_tag = YARD::Registry.at('#greet').tag(:param)
      expect([param_tag.name, param_tag.types]).to eq(['names', ['String']])
    end
  end

  describe 'method with @rbs block annotation using a plain type (&block: Proc)' do
    before do
      parse(<<~RUBY)
        # @rbs &block: Proc
        def run(&block); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#run')}

    it 'injects a @yield tag with no types' do
      expect(method_object.tag(:yield).types).to be_empty
    end

    it 'does not inject a @yieldreturn tag' do
      expect(method_object.tag(:yieldreturn)).to be_nil
    end
  end

  describe 'warning for unsupported RBS annotations' do
    it 'logs a warning for an ivar annotation' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with(/yard-inline-rbs.*unsupported.*@count: Integer/)
      parse(<<~RUBY)
        # @rbs @count: Integer
        def increment; end
      RUBY
    end
  end

  describe 'warning when RBS type cannot be parsed' do
    it 'logs a YARD warning for an unparseable @rbs annotation' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with(/yard-inline-rbs.*could not parse.*BadType!!!/)
      parse(<<~RUBY)
        # @rbs return: BadType!!!
        def broken; end
      RUBY
    end

    it 'logs a YARD warning for an unparseable method signature' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with(/yard-inline-rbs.*could not parse.*\(Integer -> String/)
      parse(<<~RUBY)
        # @rbs (Integer -> String
        def broken(count); end
      RUBY
    end

    it 'logs a YARD warning for an unparseable block annotation' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with(/yard-inline-rbs.*could not parse.*\(Integer -> void/)
      parse(<<~RUBY)
        # @rbs &block: (Integer -> void
        def broken(&block); end
      RUBY
    end

    it 'logs a YARD warning for an unparseable #: annotation' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with(/yard-inline-rbs.*could not parse.*\(Integer -> String/)
      parse(<<~RUBY)
        #: (Integer -> String
        def broken(count); end
      RUBY
    end
  end

  describe 'param annotation with the description on the lines below --' do
    before do
      parse(<<~RUBY)
        # @rbs x: Integer --
        #   the first operand,
        #   on two lines
        def add(x); end
      RUBY
    end

    it 'injects the type and the joined description' do
      param_tag = YARD::Registry.at('#add').tag(:param)
      expect([param_tag.name, param_tag.types, param_tag.text])
        .to eq(['x', ['Integer'], 'the first operand, on two lines'])
    end
  end

  describe 'method with @rbs skip' do
    before do
      parse(<<~RUBY)
        # Internal helper.
        # @rbs skip
        def debug_internal; end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#debug_internal')}

    it 'injects no tags and removes the @rbs tag' do
      expect(method_object.tags).to be_empty
    end

    it 'keeps the description' do
      expect(method_object.docstring).to eq('Internal helper.')
    end
  end

  describe 'signature with optional, rest and keyword params' do
    before do
      parse(<<~RUBY)
        # @rbs (Integer, ?Integer, *String, name: String, ?flag: bool, **Integer) -> void
        def full(x, y = 1, *rest, name:, flag: false, **opts); end
      RUBY
    end

    it 'injects a @param tag for every parameter' do
      param_tags = YARD::Registry.at('#full').tags(:param)
      expect(param_tags.to_h {|tag| [tag.name, tag.types]})
        .to eq({ 'x' => ['Integer'], 'y' => ['Integer'], 'rest' => ['String'],
                 'name' => ['String'], 'flag' => ['Boolean'], 'opts' => ['Integer'] })
    end

    it 'orders the @param tags like the Ruby parameters' do
      expect(YARD::Registry.at('#full').tags(:param).map(&:name))
        .to eq(%w[x y rest name flag opts])
    end
  end

  describe 'signature with a block' do
    before do
      parse(<<~RUBY)
        # @rbs (Hash[Symbol, untyped] config) { () -> void } -> String
        def configure(config, &block); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#configure')}

    it 'injects @yield and @yieldreturn from the block type' do
      expect([method_object.tag(:yield).types, method_object.tag(:yieldreturn).types])
        .to eq([[], ['void']])
    end

    it 'still injects @param and @return' do
      expect([method_object.tag(:param).types, method_object.tag(:return).types])
        .to eq([['Hash{Symbol => untyped}'], ['String']])
    end
  end

  describe 'unnamed splat annotations (*: Type, **: Type)' do
    before do
      parse(<<~RUBY)
        # @rbs *: String
        # @rbs **: bool
        def bar(*names, **); end
      RUBY
    end

    it 'injects @param tags named after the actual parameters' do
      param_tags = YARD::Registry.at('#bar').tags(:param)
      expect(param_tags.to_h {|tag| [tag.name, tag.types]})
        .to eq({ 'names' => ['String'], '**' => ['Boolean'] })
    end
  end

  describe 'annotations that cannot be parsed' do
    before do
      parse(<<~RUBY)
        # Does something.
        # @rbs return: BadType!!!
        def broken; end
      RUBY
    end

    it 'does not leave the raw @rbs tag in the documentation' do
      expect(YARD::Registry.at('#broken').tags).to be_empty
    end
  end

  describe 'constants, aliases and generic superclasses' do
    let(:source_file) {Tempfile.new(['constants', '.rb'])}

    before do
      source_file.write(<<~RUBY)
        class StringArray < Array #[String]
          CALLBACK = -> {} #: ^() -> void
          MyObject = Object #: class-alias
        end
      RUBY
      source_file.flush
    end

    after {source_file.close!}

    it 'logs no warnings' do
      expect(YARD::Logger.instance).not_to receive(:warn)
      YARD.parse(source_file.path)
    end

    it 'documents a proc-typed constant as Proc without the raw annotation' do
      YARD.parse(source_file.path)
      constant = YARD::Registry.at('StringArray::CALLBACK')
      expect([constant.docstring.to_s, constant.tag(:return).types]).to eq(['', ['Proc']])
    end

    it 'removes the class-alias annotation from the description' do
      YARD.parse(source_file.path)
      expect(YARD::Registry.at('StringArray::MyObject').docstring.to_s).to eq('')
    end

    it 'removes the superclass type application from the class description' do
      YARD.parse(source_file.path)
      expect(YARD::Registry.at('StringArray').docstring.to_s).to eq('')
    end
  end

  # A long-running process, such as `yard server`, parses a file again after it changes. With a
  # comment above the declaration, the trailing #: comment is read from the file.
  describe 'a file that changes between two parses' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}

    before do
      source_file.write("class Widget\n  # The count.\n  attr_reader :count #: Integer\nend\n")
      source_file.flush
      YARD.parse(source_file.path)
    end

    after {source_file.close!}

    it 'reads the annotation of the new content' do
      File.write(source_file.path,
                 "class Widget\n  # The count.\n  attr_reader :count #: String\nend\n")
      YARD.parse(source_file.path)
      expect(YARD::Registry.at('Widget#count').tag(:return).types).to eq(['String'])
    end
  end

  # YARD parses the docstring of an attribute twice, and the trailing comment is also the
  # docstring, so the plugin sees the same error several times.
  describe 'a trailing #: comment that is not valid RBS' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}

    after {source_file.close!}

    context 'with an attr_reader' do
      before do
        source_file.write("class Widget\n  attr_reader :count #: Array[\nend\n")
        source_file.flush
      end

      it 'logs one YARD warning' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/yard-inline-rbs.*:2: could not parse RBS type 'Array\['/).once
        YARD.parse(source_file.path)
      end
    end

    context 'with an attr_accessor, which declares two methods' do
      before do
        source_file.write("class Widget\n  attr_accessor :count #: Array[\nend\n")
        source_file.flush
      end

      it 'logs one YARD warning' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/yard-inline-rbs.*:2: could not parse RBS type 'Array\['/).once
        YARD.parse(source_file.path)
      end
    end

    # Without the Registry.clear, YARD would skip the unchanged file.
    context 'when the file is parsed again with a new registry' do
      before do
        source_file.write("class Widget\n  attr_reader :count #: Array[\nend\n")
        source_file.flush
        allow(YARD::Logger.instance).to receive(:warn)
        YARD.parse(source_file.path)
        YARD::Registry.clear
      end

      it 'logs the YARD warning again' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/yard-inline-rbs.*:2: could not parse RBS type 'Array\['/).once
        YARD.parse(source_file.path)
      end
    end
  end

  describe 'a docstring with hand-written descriptions' do
    before do
      parse(<<~RUBY)
        # @param [String] name The user name.
        # @return [String] The full name.
        # @rbs name: Integer
        # @rbs return: Symbol
        def described(name); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#described')}

    it 'replaces the types and keeps the descriptions' do
      expect(method_object.tags.map {|tag| [tag.tag_name, tag.types, tag.text]})
        .to contain_exactly(['param', ['Integer'], 'The user name.'],
                            ['return', ['Symbol'], 'The full name.'])
    end
  end

  describe 'a parameter annotation that is not valid RBS' do
    before do
      allow(YARD::Logger.instance).to receive(:warn)
      parse(<<~RUBY)
        # @param [String] name The user name.
        # @rbs name: Foo[
        def broken_param(name); end
      RUBY
    end

    it 'keeps the type from the docstring' do
      expect(YARD::Registry.at('#broken_param').tag(:param).types).to eq(['String'])
    end
  end

  describe 'an invalid block annotation after a valid block type' do
    before do
      allow(YARD::Logger.instance).to receive(:warn)
      parse(<<~RUBY)
        # @rbs (Integer) { (String) -> void } -> void
        # @rbs &blk: nope[
        def each_thing(x, &blk); end
      RUBY
    end

    it 'keeps documenting the block' do
      expect(YARD::Registry.at('#each_thing').tag(:yield).types).to eq(['String'])
    end
  end

  describe 'method with no RBS annotations' do
    before do
      parse(<<~RUBY)
        # @param [String] name
        # @return [Integer]
        def untouched(name); end
      RUBY
    end

    let(:method_object) {YARD::Registry.at('#untouched')}

    it 'leaves existing YARD tags intact' do
      expect(method_object.tags.map {|tag| [tag.tag_name, tag.types]})
        .to contain_exactly(['param', ['String']], ['return', ['Integer']])
    end
  end

  # A trailing comment without a comment above it is also the docstring, so the plugin reads the
  # same annotation from the docstring and from the declaration line.
  describe 'a trailing #: comment without other annotations' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}

    before do
      source_file.write(<<~RUBY)
        class Widget
          LIMIT = 3 #: Integer

          attr_reader :count #: Integer
          attr_accessor :size #: Integer

          def name #: String
          end
        end
      RUBY
      source_file.flush
    end

    after {source_file.close!}

    it 'does not warn' do
      expect(YARD::Logger.instance).not_to receive(:warn)
      YARD.parse(source_file.path)
    end
  end

  describe 'a type that is annotated twice' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}

    def parse_file(ruby_source)
      source_file.write(ruby_source)
      source_file.flush
      YARD.parse(source_file.path)
    end

    after {source_file.close!}

    context 'with a #: line above an attribute and a trailing #:' do
      it 'warns about the return type' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/widget.*\.rb:3: two RBS annotations for the return type/)
        parse_file("class Widget\n  #: Integer\n  attr_reader :size #: Integer\nend\n")
      end
    end

    context 'with a #: signature above a method and a trailing #:' do
      it 'warns about the return type' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/widget.*\.rb:3: two RBS annotations for the return type/)
        parse_file("class Widget\n  #: () -> String\n  def label #: String\n  end\nend\n")
      end
    end

    context 'with an @rbs signature and a #: signature' do
      it 'warns about the signature' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/two RBS annotations for the signature/)
        parse("# @rbs (Integer) -> String\n#: (Integer) -> String\ndef label(width); end")
      end
    end

    context 'with an @rbs parameter annotation and a signature that names it' do
      let(:source) {"# @rbs count: Integer\n#: (Float count) -> void\ndef add(count); end"}

      it 'warns about the parameter' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/two RBS annotations for parameter 'count'/)
        parse(source)
      end

      it 'keeps the first type' do
        allow(YARD::Logger.instance).to receive(:warn)
        parse(source)
        expect(YARD::Registry.at('#add').tag(:param).types).to eq(['Integer'])
      end
    end

    context 'with two @rbs block annotations' do
      it 'warns about the block' do
        expect(YARD::Logger.instance).to receive(:warn).with(/two RBS annotations for the block/)
        parse("# @rbs &block: () -> void\n# @rbs &block: () -> bool\ndef each(&block); end")
      end
    end
  end

  # YARD takes the trailing comment of a statement as the docstring of the next statement when
  # that has no comment above it: after a statement with a comment above it, or after a statement
  # over several lines.
  describe 'a trailing #: comment that YARD gives to the next statement' do
    let(:source_file) {Tempfile.new(['api', '.rb'])}

    before do
      source_file.write(<<~RUBY)
        module Api
          # Before.
          ONE = 'a' #: String -- One.

          TWO = 'b' #: Integer -- Two.

          THREE = 'c' \\
                  'd' #: Symbol -- Three.

          FOUR = 'e' #: Float -- Four.
        end
      RUBY
      source_file.flush
    end

    after {source_file.close!}

    it 'types each constant with its own trailing #:' do
      allow(YARD::Logger.instance).to receive(:warn)
      YARD.parse(source_file.path)
      expect(%w[ONE TWO FOUR].map {|name| YARD::Registry.at("Api::#{name}").tag(:return).types})
        .to eq([['String'], ['Integer'], ['Float']])
    end

    it 'does not take the description of the other statement' do
      allow(YARD::Logger.instance).to receive(:warn)
      YARD.parse(source_file.path)
      expect(YARD::Registry.at('Api::TWO').docstring.to_s).to eq('')
    end

    it 'does not warn' do
      expect(YARD::Logger.instance).not_to receive(:warn)
      YARD.parse(source_file.path)
    end
  end

  describe 'the file cache of the parse lists' do
    let(:file) {Tempfile.new(['widget', '.rb'])}

    before do
      file.write("def foo; end\n")
      file.flush
    end

    after {file.close!}

    it 'clears the cache before and after each parse list' do
      expect(YardInlineRbs::DeclarationSource).to receive(:clear_cache).twice
      YARD.parse(file.path)
    end
  end
end
