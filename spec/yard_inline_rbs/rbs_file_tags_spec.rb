# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe YardInlineRbs::RbsFileTags do
  let(:directory) {Dir.mktmpdir}
  let(:ruby_source) do
    <<~RUBY
      class Shop
        def add(item, count = 1, label: nil); end
      end
    RUBY
  end
  let(:rbs_source) do
    <<~RBS
      class Shop
        def add: (Array[String] item, ?Integer count, ?label: String?) -> bool
      end
    RBS
  end

  def ruby_commented
    <<~RUBY
      class Shop
        # Ruby description.
        # @rbs (Integer) -> String
        def both(count); end
      end
    RUBY
  end

  def rbs_commented
    <<~RBS
      class Shop
        # Sig description.
        def both: (Float) -> Float
      end
    RBS
  end

  def commented_tags
    [['param', 'count', ['Integer']], ['return', nil, ['String']]]
  end

  after {FileUtils.remove_entry(directory)}

  # Parses the files in the given order, like `yard doc` does.
  def parse_files(files)
    paths = files.map do |name, content|
      path = File.join(directory, name)
      File.write(path, content)
      path
    end
    YARD.parse(paths)
  end

  def tags_of(path)
    YARD::Registry.at(path).tags.map {|tag| [tag.tag_name, tag.name, tag.types]}
  end

  describe '.apply' do
    context 'when the Ruby file is parsed before the .rbs file' do
      before {parse_files('shop.rb' => ruby_source, 'shop.rbs' => rbs_source)}

      it 'tags the method with the declared types, in YARD notation' do
        expect(tags_of('Shop#add'))
          .to eq([['param', 'item', ['Array<String>']],
                  ['param', 'count', ['Integer']],
                  ['param', 'label', ['String, nil']],
                  ['return', nil, ['Boolean']]])
      end
    end

    context 'when the .rbs file is parsed before the Ruby file' do
      before {parse_files('shop.rbs' => rbs_source, 'shop.rb' => ruby_source)}

      it 'tags the method with the declared types, like in the other order' do
        expect(tags_of('Shop#add'))
          .to eq([['param', 'item', ['Array<String>']],
                  ['param', 'count', ['Integer']],
                  ['param', 'label', ['String, nil']],
                  ['return', nil, ['Boolean']]])
      end
    end

    context 'with a method that only exists in the .rbs file' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def find: (String, ?Integer) -> void
          end
        RBS
      end

      it 'names the parameters arg0, arg1, ...' do
        expect(tags_of('Shop#find'))
          .to eq([['param', 'arg0', ['String']], ['param', 'arg1', ['Integer']],
                  ['return', nil, ['void']]])
      end
    end

    context 'when the Ruby docstring already has tags' do
      before do
        parse_files('shop.rb' => <<~RUBY, 'shop.rbs' => rbs_source)
          class Shop
            # @param [Symbol] item The item.
            def add(item, count = 1, label: nil); end
          end
        RUBY
      end

      it 'keeps the tags of the docstring and adds the missing ones' do
        expect(tags_of('Shop#add').first(2))
          .to eq([['param', 'item', ['Symbol']], ['param', 'count', ['Integer']]])
      end
    end

    context 'when the method also has an inline annotation' do
      before do
        parse_files('shop.rbs' => <<~RBS, 'shop.rb' => <<~RUBY)
          class Shop
            def add: (String item, Integer count) -> bool
          end
        RBS
          class Shop
            # @rbs (Float, Float) -> Float
            def add(item, count); end
          end
        RUBY
      end

      it 'prefers the inline annotation' do
        expect(tags_of('Shop#add'))
          .to eq([['param', 'item', ['Float']], ['param', 'count', ['Float']],
                  ['return', nil, ['Float']]])
      end
    end

    context 'when a .rbs file and an inline annotation type the same method' do
      let(:warnings) {[]}

      before do
        allow(YARD::Logger.instance).to receive(:warn) {|message| warnings << message}
        ruby = "class Shop\n  # @rbs (Float) -> Float\n  def add(item); end\nend\n"
        rbs = "class Shop\n  def add: (String item) -> bool\nend\n"
        parse_files('shop.rbs' => rbs, 'shop.rb' => ruby)
      end

      it 'warns about each type, at the Ruby declaration' do
        expect(warnings.map {|warning| warning.gsub(directory, 'dir')})
          .to eq(["[yard-inline-rbs] dir/shop.rb:3: two RBS annotations for parameter 'item', "\
                  'one in dir/shop.rbs',
                  '[yard-inline-rbs] dir/shop.rb:3: two RBS annotations for the return type, '\
                  'one in dir/shop.rbs'])
      end
    end

    context 'when a .rbs file and a trailing #: type the same attribute' do
      it 'warns about the return type' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/shop\.rb:2: two RBS annotations for the return type, one in .*shop\.rbs/)
        parse_files('shop.rbs' => "class Shop\n  attr_reader name: Symbol\nend\n",
                    'shop.rb' => "class Shop\n  attr_reader :name #: String\nend\n")
      end
    end

    context 'when a method with an inline annotation is defined again with another comment' do
      before do
        rbs = "class Shop\n  def add: (String) -> bool | (Integer) -> nil\nend\n"
        parse_files('shop.rbs' => rbs, 'shop.rb' => <<~RUBY)
          class Shop
            #: (Float) -> Float
            def add(item); end

            # Adds an item.
            def add(item); end
          end
        RUBY
      end

      it 'documents the .rbs signatures, without a warning' do
        expect(YARD::Registry.at('Shop#add').tags(:overload).size).to eq(2)
      end
    end

    context 'when the annotated definition of a method is not the first one' do
      it 'warns at the annotated definition' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/shop\.rb:6: two RBS annotations for the return type, one in .*shop\.rbs/)
        parse_files('shop.rbs' => "class Shop\n  def size: () -> Integer\nend\n",
                    'shop.rb' => <<~RUBY)
                      class Shop
                        # The size.
                        def size; end
                      end
                      class Shop
                        def size = 1 #: Integer
                      end
                    RUBY
      end
    end

    # A long-running process, such as `yard server`, parses the files again after a change.
    context 'when the inline type is removed before the next parse' do
      before do
        allow(YARD::Logger.instance).to receive(:warn)
        parse_files('shop.rbs' => "class Shop\n  attr_reader name: Symbol\nend\n",
                    'shop.rb' => "class Shop\n  attr_reader :name #: String\nend\n")
      end

      it 'does not warn again' do
        expect(YARD::Logger.instance).not_to receive(:warn)
        parse_files('shop.rbs' => "class Shop\n  attr_reader name: Symbol\nend\n",
                    'shop.rb' => "class Shop\n  attr_reader :name\nend\n")
      end
    end

    context 'when a .rbs file has several signatures for a method with an inline annotation' do
      def parse_overloads
        rbs = "class Shop\n  def add: (String) -> bool | (Integer) -> nil\nend\n"
        parse_files('shop.rbs' => rbs,
                    'shop.rb' => "class Shop\n  #: (Float) -> Float\n  def add(item); end\nend\n")
      end

      it 'keeps the inline types and adds no @overload tags' do
        allow(YARD::Logger.instance).to receive(:warn)
        parse_overloads
        expect(tags_of('Shop#add'))
          .to eq([['param', 'item', ['Float']], ['return', nil, ['Float']]])
      end

      it 'warns about the signature' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/two RBS annotations for the signature, one in .*shop\.rbs/)
        parse_overloads
      end
    end

    context 'when a .rbs file and a YARD tag type the same parameter' do
      it 'does not warn' do
        expect(YARD::Logger.instance).not_to receive(:warn)
        parse_files('shop.rb' => <<~RUBY, 'shop.rbs' => rbs_source)
          class Shop
            # @param [Symbol] item The item.
            def add(item, count = 1, label: nil); end
          end
        RUBY
      end
    end

    context 'with a commented .rbs member and an inline annotation, Ruby file first' do
      before {parse_files('shop.rb' => ruby_commented, 'shop.rbs' => rbs_commented)}

      it 'keeps the inline annotation and the Ruby description' do
        expect([YARD::Registry.at('Shop#both').docstring.to_s, tags_of('Shop#both')])
          .to eq(['Ruby description.', commented_tags])
      end
    end

    context 'with a commented .rbs member and an inline annotation, .rbs file first' do
      before {parse_files('shop.rbs' => rbs_commented, 'shop.rb' => ruby_commented)}

      it 'keeps the inline annotation and the Ruby description' do
        expect([YARD::Registry.at('Shop#both').docstring.to_s, tags_of('Shop#both')])
          .to eq(['Ruby description.', commented_tags])
      end
    end

    context 'with a commented .rbs member and a Ruby method without description' do
      before do
        parse_files('shop.rb' => "class Shop\n  def both(count); end\nend\n",
                    'shop.rbs' => rbs_commented)
      end

      it 'shows the description of the .rbs file' do
        expect(YARD::Registry.at('Shop#both').docstring.to_s).to eq('Sig description.')
      end
    end

    context 'with a method with several signatures' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def add: (String) -> bool | (Integer, ?label: Symbol) -> nil
          end
        RBS
      end

      it 'adds an @overload tag for each signature' do
        expect(YARD::Registry.at('Shop#add').tags(:overload).map(&:signature))
          .to eq(['add(arg0)', 'add(arg0, label:)'])
      end
    end

    context 'with a block' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def each: () { (String) -> void } -> void
          end
        RBS
      end

      it 'adds @yield and @yieldreturn tags' do
        expect(tags_of('Shop#each').map(&:first)).to eq(%w[return yield yieldreturn])
      end
    end

    context 'with a method without parameter types' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def anything: (?) -> untyped
          end
        RBS
      end

      it 'tags only the return type' do
        expect(tags_of('Shop#anything')).to eq([['return', nil, ['untyped']]])
      end
    end

    context 'with initialize' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def initialize: (String name) -> void
          end
        RBS
      end

      it 'keeps the return tag that YARD adds for a new instance' do
        expect(tags_of('Shop#initialize').last).to eq(['return', nil, ['Shop']])
      end
    end

    context 'with singleton methods' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def self.build: () -> Shop
          end
        RBS
      end

      it 'tags the class method' do
        expect(tags_of('Shop.build')).to eq([['return', nil, ['Shop']]])
      end
    end

    context 'with a module function' do
      before do
        parse_files('util.rbs' => <<~RBS, 'util.rb' => <<~RUBY)
          module Util
            def self?.helper: (Integer) -> String
          end
        RBS
          module Util
            module_function

            def helper(count); end
          end
        RUBY
      end

      it 'tags both the class and the instance method' do
        expect([tags_of('Util.helper'), tags_of('Util#helper')].uniq)
          .to eq([[['param', 'count', ['Integer']], ['return', nil, ['String']]]])
      end
    end

    context 'with attributes' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            attr_reader owner: String?
            attr_writer budget: Integer
            attr_accessor tags: Array[Symbol]
          end
        RBS
      end

      it 'tags a reader with a return type' do
        expect(tags_of('Shop#owner')).to eq([['return', nil, ['String, nil']]])
      end

      it 'tags a writer with a parameter type' do
        expect(tags_of('Shop#budget=')).to eq([['param', 'value', ['Integer']]])
      end

      it 'tags both methods of an accessor' do
        expect([tags_of('Shop#tags'), tags_of('Shop#tags=')])
          .to eq([[['return', nil, ['Array<Symbol>']]], [['param', 'value', ['Array<Symbol>']]]])
      end
    end

    # The Ruby comments replace the docstrings, and so the tags, that YARD's .rbs handlers wrote.
    context 'with commented Ruby attributes and constants' do
      before do
        parse_files('shop.rbs' => <<~RBS, 'shop.rb' => <<~RUBY)
          class Shop
            LIMIT: Integer
            attr_reader owner: String?
            attr_writer budget: Float
            attr_accessor tags: Array[Symbol]
          end
        RBS
          class Shop
            # The limit.
            LIMIT = 10

            # The owner.
            attr_reader :owner

            # The budget.
            attr_writer :budget

            # The tags.
            attr_accessor :tags
          end
        RUBY
      end

      it 'tags the constant' do
        expect(tags_of('Shop::LIMIT')).to eq([['return', nil, ['Integer']]])
      end

      it 'tags the reader' do
        expect(tags_of('Shop#owner')).to eq([['return', nil, ['String, nil']]])
      end

      it 'tags the writer' do
        expect(tags_of('Shop#budget=')).to eq([['param', 'value', ['Float']]])
      end

      it 'tags both methods of the accessor' do
        expect([tags_of('Shop#tags'), tags_of('Shop#tags=')])
          .to eq([[['return', nil, ['Array<Symbol>']]], [['param', 'value', ['Array<Symbol>']]]])
      end
    end

    context 'with Ruby accessors declared as a reader or a writer in the .rbs file' do
      before do
        parse_files('shop.rbs' => <<~RBS, 'shop.rb' => <<~RUBY)
          class Shop
            attr_reader owner: String
            attr_writer budget: Float
          end
        RBS
          class Shop
            # The owner.
            attr_accessor :owner

            # The budget.
            attr_accessor :budget
          end
        RUBY
      end

      it 'tags only the declared method' do
        expect(%w[Shop#owner Shop#owner= Shop#budget Shop#budget=].map {|path| tags_of(path)})
          .to eq([[['return', nil, ['String']]], [], [], [['param', 'value', ['Float']]]])
      end
    end

    context 'with an absolute class name inside a module' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          module Outer
            class ::Foo::Bar
              def run: () -> bool
            end
          end
        RBS
      end

      it 'tags the method of the class at the top level' do
        expect(tags_of('Foo::Bar#run')).to eq([['return', nil, ['Boolean']]])
      end
    end

    context 'with overloads and a block' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          class Shop
            def each: () { (String) -> void } -> void | (Integer) -> bool
          end
        RBS
      end

      it 'documents the block in the overload that has one' do
        overload = YARD::Registry.at('Shop#each').tags(:overload).first
        expect(overload.tags.map(&:tag_name)).to contain_exactly('yield', 'yieldreturn', 'return')
      end
    end

    context 'with constants and nested namespaces' do
      before do
        parse_files('shop.rbs' => <<~RBS)
          VERSION: String

          module Outer
            class Inner
              LIMIT: Integer
              def run: () -> bool
            end
          end
        RBS
      end

      it 'tags a top-level constant' do
        expect(tags_of('VERSION')).to eq([['return', nil, ['String']]])
      end

      it 'tags a constant and a method of a nested class' do
        expect([tags_of('Outer::Inner::LIMIT'), tags_of('Outer::Inner#run')])
          .to eq([[['return', nil, ['Integer']]], [['return', nil, ['Boolean']]]])
      end
    end

    context 'with declarations without a YARD object' do
      it 'ignores interfaces and methods that YARD does not know' do
        expect do
          parse_files('shop.rbs' => <<~RBS)
            interface _Each
              def each: () -> void
            end
            type name = String
          RBS
        end.not_to raise_error
      end
    end

    context 'with a .rbs file that is not valid RBS' do
      let(:broken_source) {"class Shop\n  def add: (\nend\n"}

      before {allow(YARD::Logger.instance).to receive(:warn)}

      it 'warns about the file' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/yard-inline-rbs\] .*broken\.rbs: /).at_least(:once)
        parse_files('broken.rbs' => broken_source)
      end

      it 'continues with the other files' do
        parse_files('broken.rbs' => broken_source)
        expect(YARD::Registry.at('Shop')).not_to be_nil
      end
    end

    # YARD's object.file and object.line are those of the first declaration with a comment: the
    # .rbs file, which the plugin parses first.
    context 'with a commented .rbs declaration and a trailing #: in Ruby below a comment' do
      before do
        parse_files('shop.rb' => "class Shop\n  # The name.\n  attr_reader :name #: String\nend\n",
                    'shop.rbs' => "class Shop\n  # Sig.\n  attr_reader name: Symbol\nend\n")
      end

      it 'documents the Ruby type' do
        expect(tags_of('Shop#name')).to eq([['return', nil, ['String']]])
      end
    end

    # YARD reads a Ruby comment that only holds annotations as the new docstring.
    context 'with a commented .rbs declaration and only annotations in Ruby' do
      before do
        parse_files('shop.rb' => <<~RUBY, 'shop.rbs' => <<~RBS)
          class Shop
            attr_reader :name #: String

            #: (Integer) -> String
            def label(width); end
          end
        RUBY
          class Shop
            # The name in sig.
            attr_reader name: Symbol
            # The label in sig.
            def label: (Float) -> Float
          end
        RBS
      end

      it 'keeps the .rbs description of the attribute and documents the Ruby type' do
        expect([YARD::Registry.at('Shop#name').docstring.to_s, tags_of('Shop#name')])
          .to eq(['The name in sig.', [['return', nil, ['String']]]])
      end

      it 'keeps the .rbs description of the method' do
        expect(YARD::Registry.at('Shop#label').docstring.to_s).to eq('The label in sig.')
      end
    end

    context 'with a commented .rbs declaration and an invalid annotation in Ruby' do
      it 'warns with the location of the Ruby declaration' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(%r{yard-inline-rbs\] .*/shop\.rb:3: could not parse RBS type 'Array\['})
        parse_files('shop.rb' => "class Shop\n  # @rbs item: Array[\n  def add(item); end\nend\n",
                    'shop.rbs' => "class Shop\n  # Sig.\n  def add: (String item) -> void\nend\n")
      end
    end

    context 'with a commented .rbs class and a generic superclass in Ruby' do
      before do
        parse_files('list.rb' => "# A list.\nclass List < Array #[String]\nend\n",
                    'list.rbs' => "# Sig.\nclass List < Array[String]\nend\n")
      end

      it 'removes the type application from the description' do
        expect(YARD::Registry.at('List').docstring.to_s).to eq('A list.')
      end
    end

    # RbsHandlerPatches falls back to YARD's own conversion without a warning of its own.
    context 'with a .rbs file that has an invalid type for a constant' do
      it 'warns about the file once' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with(/yard-inline-rbs\] .*shop\.rbs: .*Syntax error/).once
        parse_files('shop.rbs' => "class Shop\n  NAME: Array[\nend\n")
      end
    end
  end

  describe '.parse_rbs_first' do
    it 'moves the .rbs files to the front, in place and in order' do
      files = %w[a.rb x.rbs b.rb y.rbs]
      described_class.parse_rbs_first(files)
      expect(files).to eq(%w[x.rbs y.rbs a.rb b.rb])
    end
  end

  describe '#initialize' do
    it 'does not read the file yet' do
      expect {described_class.new('does/not/exist.rbs')}.not_to raise_error
    end
  end

  describe '#apply' do
    let(:path) {File.join(directory, 'shop.rbs')}

    before do
      File.write(path, "class Shop\n  def add: (String) -> bool\nend\n")
      YARD.parse_string('class Shop; def add(item); end; end')
    end

    it 'tags the objects of a file that is already parsed' do
      described_class.new(path).apply
      expect(tags_of('Shop#add'))
        .to eq([['param', 'item', ['String']], ['return', nil, ['Boolean']]])
    end

    context 'with a file that has UTF-16 content' do
      before {File.binwrite(path, "class Shop\nend\n".encode('UTF-16LE'))}

      it 'warns and skips the file' do
        expect(YARD::Logger.instance).to receive(:warn).with(/yard-inline-rbs\] .*shop\.rbs: /)
        described_class.new(path).apply
      end
    end

    context 'with a file that has invalid UTF-8 bytes' do
      before {File.binwrite(path, "class Shop\n  def add: () -> void # \xFF\xFE\nend\n".b)}

      it 'warns and skips the file' do
        expect(YARD::Logger.instance).to receive(:warn).with(/yard-inline-rbs\] .*shop\.rbs: /)
        described_class.new(path).apply
      end
    end

    context 'with a file that does not exist' do
      before {FileUtils.rm_f(path)}

      it 'warns and skips the file' do
        expect(YARD::Logger.instance).to receive(:warn).with(/yard-inline-rbs\] .*shop\.rbs: /)
        described_class.new(path).apply
      end
    end

    context 'when YARD has no object for the declaration' do
      before {YARD::Registry.clear}

      it 'does nothing' do
        expect {described_class.new(path).apply}.not_to raise_error
      end
    end
  end
end
